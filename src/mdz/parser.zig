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
        '>' => try w.printAscii("&gt;", .{}),
        '<' => try w.printAscii("&lt;", .{}),
        '&' => try w.printAscii("&amp;", .{}),
        else => try w.printAsciiChar(c, .{}),
    }
}

const ProcessInlinesError = Writer.Error || std.fmt.ParseIntError;

fn processInlines(line: []u8, w: *Writer, state: *ast.BlockState) ProcessInlinesError!void {
    var ref_index: ?usize = null;
    var i: usize = 0;
    while (i < line.len) : (i += 1) {
        if (state.flags.is_code) {
            @branchHint(.unlikely);
            switch (line[i]) {
                '\\' => {
                    i += 1;
                    if (i < line.len) {
                        @branchHint(.likely);
                        try printEscapedHtml(line[i], w);
                    }
                },
                '`' => {
                    try w.printAscii("</code>", .{});
                    state.flags.is_code = false;
                },
                else => try printEscapedHtml(line[i], w),
            }
            continue;
        }
        switch (line[i]) {
            '`' => {
                try w.printAscii("<code>", .{});
                state.flags.is_code = true;
            },
            '*' => {
                if (i + 1 < line.len and line[i + 1] == '*') {
                    i += 1;
                    if (state.flags.is_strong) {
                        try w.printAscii("</strong>", .{});
                    } else {
                        try w.printAscii("<strong>", .{});
                    }
                    state.flags.is_strong = !state.flags.is_strong;
                } else {
                    if (state.flags.is_em) {
                        try w.printAscii("</em>", .{});
                    } else {
                        try w.printAscii("<em>", .{});
                    }
                    state.flags.is_em = !state.flags.is_em;
                }
            },
            '[' => {
                if (i + 1 < line.len and line[i + 1] == '^') {
                    i += 1;
                    ref_index = i + 1;
                    state.flags.is_footnote_citation = true;
                    try w.printAscii("<sup class=\"footnote-ref\"><a href=\"#fn", .{});
                } else {
                    state.flags.is_link = true;
                    ref_index = i;
                    try w.printAscii("<a href=\"", .{});
                    i = i + std.mem.indexOf(u8, line[i..], "](").? + 1;
                }
            },
            ')' => {
                if (state.flags.is_link) {
                    const new_ref_index = i;
                    i = ref_index.?;
                    ref_index = new_ref_index;
                    try w.printAscii("\">", .{});
                } else {
                    try w.printAsciiChar(line[i], .{});
                }
            },
            ']' => {
                if (state.flags.is_link) {
                    try w.printAscii("</a>", .{});
                    i = ref_index.?;
                    state.flags.is_link = false;
                    ref_index = null;
                } else if (state.flags.is_footnote_citation) {
                    const fn_key = try std.fmt.parseInt(u8, line[ref_index.?..i], 10);
                    const fn_num = state.footnotes[fn_key];

                    if (fn_num > 0) {
                        try w.print("\" id=\"fnref{d}:{d}\">[{d}:{d}]</a></sup>", .{ fn_key, fn_num, fn_key, fn_num });
                    } else {
                        try w.print("\" id=\"fnref{d}\">[{d}]</a></sup>", .{ fn_key, fn_key });
                    }
                    state.footnotes[fn_key] += 1;
                    state.flags.is_footnote_citation = false;
                    ref_index = null;
                }
            },
            '\\' => {
                i += 1;
                if (i < line.len) {
                    @branchHint(.likely);
                    try printEscapedHtml(line[i], w);
                }
            },
            else => try w.printAsciiChar(line[i], .{}),
        }
    }
}

fn processFootnoteReference(line: []u8, w: *Writer, state: *ast.BlockState) ProcessInlinesError!void {
    std.debug.assert(std.mem.eql(u8, line[0..2], "[^"));
    var i: usize = 2;
    while (i < line.len and line[i] != ']') : (i += 1) {}
    const fn_key = try std.fmt.parseInt(u8, line[2..i], 10);
    try w.print("<li id=\"fn{d}\" class=\"footnote-item\"><p>", .{fn_key});
    try processInlines(line[i + 3 ..], w, state);
    var j: usize = 0;
    while (j < state.footnotes[fn_key]) : (j += 1) {
        if (j > 0) {
            try w.print(" <a href=\"#fnref{d}:{d}\" class=\"footnote-backref\">↩︎</a>", .{ fn_key, j });
        } else {
            try w.print(" <a href=\"#fnref{d}\" class=\"footnote-backref\">↩︎</a>", .{fn_key});
        }
    }
    try w.printAscii("</p></li>\n", .{});
}

fn closeBlocks(w: *Writer, state: *ast.BlockState, depth: usize) Writer.Error!void {
    while (state.len > depth) : ({
        state.items[state.len - 1] = null;
        state.len -= 1;
    }) switch (state.items[state.len - 1].?) {
        .block_quote => try w.printAscii("</blockquote>\n", .{}),
        .unordered_list => try w.printAscii("</li>\n</ul>\n", .{}),
        .ordered_list => try w.printAscii("</li>\n</ol>\n", .{}),
        .paragraph => try w.printAscii("</p>\n", .{}),
        .paragraph_hidden, .html_block => {},
        .code_block => try w.printAscii("</code></pre>\n", .{}),
        .footnote_reference => try w.printAscii("</ol>\n", .{}),
    };
}

const ProcessLineError = Writer.Error || ast.StackError || std.fmt.ParseIntError;

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
                    try w.printAscii("</li>\n<li>", .{});
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
                    try w.printAscii("</li>\n<li>", .{});
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
                    try w.printAsciiChar('\n', .{}); // lazy continuation
                    try processInlines(line, w, state);
                }
                return;
            },
            .paragraph_hidden => {
                try w.printAsciiChar('\n', .{}); // lazy continuation
                break;
            },
            .code_block => {
                if (line.len > 2 and std.mem.eql(u8, line[0..3], "```")) {
                    try closeBlocks(w, state, depth);
                } else {
                    for (line) |c| try printEscapedHtml(c, w);
                    try w.printAsciiChar('\n', .{});
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
            .footnote_reference => {
                if (line.len > 1 and std.mem.eql(u8, line[0..2], "[^")) {
                    try processFootnoteReference(line, w, state);
                    return;
                } else {
                    try closeBlocks(w, state, depth);
                }
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
        try w.printAscii("<blockquote>\n", .{});
        return processLine(line[2..], w, state, depth + 1);
    } else if (line.len > 1 and std.mem.eql(u8, line[0..2], "* ")) { // unordered list
        try state.push(.unordered_list);
        try w.printAscii("<ul>\n<li>", .{});
        return processLine(line[2..], w, state, depth + 1);
    } else if (line.len > 2 and std.mem.eql(u8, line[0..3], "1. ")) { // ordered list
        try state.push(.ordered_list);
        try w.printAscii("<ol>\n<li>", .{});
        return processLine(line[3..], w, state, depth + 1);
    } else if (line.len > 2 and std.mem.eql(u8, line[0..3], "```")) { // code block
        try state.push(.code_block);
        try w.printAscii("<pre><code", .{});
        if (line[3..].len > 0) {
            try w.print(" class=\"language-{s}\"", .{line[3..]});
        }
        try w.printAsciiChar('>', .{});
        return;
    } else if (line.len > 6 and std.mem.eql(u8, line[0..7], "###### ")) { // heading 6
        try w.printAscii("<h6>", .{});
        try processInlines(line[7..], w, state);
        try w.printAscii("</h6>\n", .{});
        return;
    } else if (line.len > 5 and std.mem.eql(u8, line[0..6], "##### ")) { // heading 5
        try w.printAscii("<h5>", .{});
        try processInlines(line[6..], w, state);
        try w.printAscii("</h5>\n", .{});
        return;
    } else if (line.len > 4 and std.mem.eql(u8, line[0..5], "#### ")) { // heading 4
        try w.printAscii("<h4>", .{});
        try processInlines(line[5..], w, state);
        try w.printAscii("</h4>\n", .{});
        return;
    } else if (line.len > 3 and std.mem.eql(u8, line[0..4], "### ")) { // heading 3
        try w.printAscii("<h3>", .{});
        try processInlines(line[4..], w, state);
        try w.printAscii("</h3>\n", .{});
        return;
    } else if (line.len > 2 and std.mem.eql(u8, line[0..3], "## ")) { // heading 2
        try w.printAscii("<h2>", .{});
        try processInlines(line[3..], w, state);
        try w.printAscii("</h2>\n", .{});
        return;
    } else if (line.len > 1 and std.mem.eql(u8, line[0..2], "# ")) { // heading 1
        try w.printAscii("<h1>", .{});
        try processInlines(line[2..], w, state);
        try w.printAscii("</h1>\n", .{});
        return;
    } else if (line.len > 1 and std.mem.eql(u8, line[0..2], "[^")) { // footnote reference
        try state.push(.footnote_reference);
        try w.printAscii("<ol class=\"footnotes-list\">\n", .{});
        try processFootnoteReference(line, w, state);
        return;
    } else if (line.len == 3 and std.mem.eql(u8, line, "---")) { // thematic break
        try w.printAscii("<hr />\n", .{});
        return;
    } else if (line.len > 1 and line[0] == '<' and std.ascii.isAlphabetic(line[1])) { // HTML block
        try state.push(.html_block);
        try processLine(line, w, state, depth);
        return;
    } else { // paragraph
        if (state.len == 0) {
            try state.push(.paragraph);
            try w.printAscii("<p>", .{});
        } else {
            switch (state.items[state.len - 1].?) {
                .unordered_list,
                .ordered_list,
                => try state.push(.paragraph_hidden),
                .paragraph => unreachable,
                .paragraph_hidden => {},
                else => {
                    try state.push(.paragraph);
                    try w.printAscii("<p>", .{});
                },
            }
        }
    }

    //
    // process leaf blocks
    //

    try processInlines(line, w, state);
}

pub const ProcessDocumentError = error{ ReadFailed, StreamTooLong } || ProcessLineError;

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
