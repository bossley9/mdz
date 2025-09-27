const std = @import("std");
const ast = @import("./ast.zig");

const Reader = std.io.Reader;
const Writer = std.io.Writer;

/// Custom implementation of `std.io.Reader.takeDelimiterExclusive` to
/// account for different line endings (LF/CRLF) and optional EOF LF.
fn takeNewlineExclusive(r: *Reader) Reader.DelimiterError![]u8 {
    const result = r.peekDelimiterInclusive('\n') catch |err| switch (err) {
        Reader.DelimiterError.EndOfStream, Reader.DelimiterError.StreamTooLong => {
            const remaining = r.buffer[r.seek..r.end];
            if (remaining.len == 0) return error.EndOfStream;
            r.toss(remaining.len);
            return remaining;
        },
        else => |e| return e,
    };
    r.toss(result.len);

    if (result.len > 1 and result[result.len - 2] == '\r') {
        @branchHint(.cold);
        return result[0 .. result.len - 2];
    }

    return result[0 .. result.len - 1];
}

fn printEscapedHtml(c: u8, w: *Writer) Writer.Error!void {
    switch (c) {
        '>' => try w.print("&gt;", .{}),
        '<' => try w.print("&lt;", .{}),
        '&' => try w.print("&amp;", .{}),
        else => try w.print("{c}", .{c}),
    }
}

fn processInlines(inlines: []u8, w: *Writer) Writer.Error!void {
    var i: usize = 0;
    while (i < inlines.len) : (i += 1) {
        switch (inlines[i]) {
            '\\' => {
                i += 1;
                if (i < inlines.len) {
                    @branchHint(.likely);
                    try printEscapedHtml(inlines[i], w);
                }
            },
            else => try w.print("{c}", .{inlines[i]}),
        }
    }
}

fn closeBlocks(w: *Writer, state: *ast.BlockState, depth: usize) Writer.Error!void {
    while (state.len > depth) : ({
        state.items[state.len - 1] = null;
        state.len -= 1;
    }) switch (state.items[state.len - 1].?) {
        .block_quote => try w.print("</blockquote>\n", .{}),
        .unordered_list => try w.print("</li>\n</ul>\n", .{}),
        .ordered_list => try w.print("</li>\n</ol>\n", .{}),
        .paragraph => try w.print("</p>\n", .{}),
        .paragraph_hidden => {},
        .code_block => try w.print("</code></pre>\n", .{}),
        .html_block => {},
    };
}

const ProcessLineError = Writer.Error || ast.StackError;

fn processLine(starting_line: []u8, w: *Writer, state: *ast.BlockState, starting_depth: usize) ProcessLineError!void {
    var depth = starting_depth;
    var line = starting_line;

    //
    // validate existing blocks
    //

    while (depth < state.len) : (depth += 1) {
        const block = state.items[depth].?;
        switch (block) {
            .block_quote => {
                if (line.len > 1 and std.mem.eql(u8, line[0..2], "> ")) {
                    line = line[2..];
                } else {
                    try closeBlocks(w, state, depth);
                    break;
                }
            },
            .unordered_list => {
                if (line.len > 1 and std.mem.eql(u8, line[0..2], "  ")) {
                    line = line[2..];
                } else if (line.len > 1 and std.mem.eql(u8, line[0..2], "* ")) {
                    try closeBlocks(w, state, depth + 1);
                    try w.print("</li>\n<li>", .{});
                    line = line[2..];
                } else {
                    try closeBlocks(w, state, depth);
                    break;
                }
            },
            .ordered_list => {
                if (line.len > 2 and std.mem.eql(u8, line[0..3], "   ")) {
                    line = line[3..];
                } else if (line.len > 2 and std.mem.eql(u8, line[0..3], "1. ")) {
                    try closeBlocks(w, state, depth + 1);
                    try w.print("</li>\n<li>", .{});
                    line = line[3..];
                } else {
                    try closeBlocks(w, state, depth);
                    break;
                }
            },
            .paragraph => {
                if (line.len == 0) {
                    try closeBlocks(w, state, depth);
                } else {
                    try w.print("\n", .{}); // lazy continuation
                    try processInlines(line, w);
                }
                return;
            },
            .paragraph_hidden => {
                try w.print("\n", .{}); // lazy continuation
                break;
            },
            .code_block => {
                if (line.len > 2 and std.mem.eql(u8, line[0..3], "```")) {
                    try closeBlocks(w, state, depth);
                } else {
                    for (line) |c| try printEscapedHtml(c, w);
                    try w.print("\n", .{});
                }
                return;
            },
            .html_block => {
                if (line.len == 0) {
                    try closeBlocks(w, state, depth);
                } else {
                    try w.print("{s}\n", .{line});
                }
                return;
            },
        }
    }

    //
    // close blocks for blank lines
    //

    if (line.len == 0) {
        return closeBlocks(w, state, depth);
    }

    //
    // create new blocks
    //

    if (line.len > 1 and std.mem.eql(u8, line[0..2], "> ")) { // block quote
        try state.push(.block_quote);
        try w.print("<blockquote>\n", .{});
        return processLine(line[2..], w, state, depth + 1);
    } else if (line.len > 1 and std.mem.eql(u8, line[0..2], "* ")) { // unordered list
        try state.push(.unordered_list);
        try w.print("<ul>\n<li>", .{});
        return processLine(line[2..], w, state, depth + 1);
    } else if (line.len > 2 and std.mem.eql(u8, line[0..3], "1. ")) { // ordered list
        try state.push(.ordered_list);
        try w.print("<ol>\n<li>", .{});
        return processLine(line[3..], w, state, depth + 1);
    } else if (line.len > 2 and std.mem.eql(u8, line[0..3], "```")) { // code block
        try state.push(.code_block);
        if (line[3..].len > 0) {
            try w.print("<pre><code class=\"language-{s}\">", .{line[3..]});
        } else {
            try w.print("<pre><code>", .{});
        }
        return;
    } else if (line.len > 6 and std.mem.eql(u8, line[0..7], "###### ")) { // heading 6
        try w.print("<h6>", .{});
        try processInlines(line[7..], w);
        try w.print("</h6>\n", .{});
        return;
    } else if (line.len > 5 and std.mem.eql(u8, line[0..6], "##### ")) { // heading 5
        try w.print("<h5>", .{});
        try processInlines(line[6..], w);
        try w.print("</h5>\n", .{});
        return;
    } else if (line.len > 4 and std.mem.eql(u8, line[0..5], "#### ")) { // heading 4
        try w.print("<h4>", .{});
        try processInlines(line[5..], w);
        try w.print("</h4>\n", .{});
        return;
    } else if (line.len > 3 and std.mem.eql(u8, line[0..4], "### ")) { // heading 3
        try w.print("<h3>", .{});
        try processInlines(line[4..], w);
        try w.print("</h3>\n", .{});
        return;
    } else if (line.len > 2 and std.mem.eql(u8, line[0..3], "## ")) { // heading 2
        try w.print("<h2>", .{});
        try processInlines(line[3..], w);
        try w.print("</h2>\n", .{});
        return;
    } else if (line.len > 1 and std.mem.eql(u8, line[0..2], "# ")) { // heading 1
        try w.print("<h1>", .{});
        try processInlines(line[2..], w);
        try w.print("</h1>\n", .{});
        return;
    } else if (line.len == 3 and std.mem.eql(u8, line, "---")) { // thematic break
        try w.print("<hr />\n", .{});
        return;
    } else if (line.len > 1 and line[0] == '<' and std.ascii.isAlphabetic(line[1])) { // HTML block
        try state.push(.html_block);
        try processLine(line, w, state, depth);
        return;
    } else { // paragraph
        if (state.len == 0) {
            try state.push(.paragraph);
            try w.print("<p>", .{});
        } else {
            switch (state.items[state.len - 1].?) {
                .unordered_list,
                .ordered_list,
                => try state.push(.paragraph_hidden),
                .paragraph => unreachable,
                .paragraph_hidden => {},
                else => {
                    try state.push(.paragraph);
                    try w.print("<p>", .{});
                },
            }
        }
    }

    //
    // process leaf blocks
    //

    try processInlines(line, w);
}

pub const ProcessDocumentError = error{ ReadFailed, StreamTooLong, WriteFailed } || ast.StackError;

/// Read an MDZ document from an input reader and incrementally write
/// the output to writer.
pub fn processDocument(r: *Reader, w: *Writer) ProcessDocumentError!void {
    var state = ast.BlockState.init();

    while (takeNewlineExclusive(r)) |line| {
        try processLine(line, w, &state, 0);
    } else |e| switch (e) {
        Reader.DelimiterError.EndOfStream => {}, // end of input
        Reader.DelimiterError.ReadFailed,
        Reader.DelimiterError.StreamTooLong,
        => |err| return err,
    }
    try closeBlocks(w, &state, 0); // close remaining blocks

    if (w.end > 0) w.undo(1); // omit final newline
}
