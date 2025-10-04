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
        '>' => _ = try w.write("&gt;"),
        '<' => _ = try w.write("&lt;"),
        '&' => _ = try w.write("&amp;"),
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
                    _ = try w.write("</code>");
                    state.flags.is_code = false;
                },
                else => try printEscapedHtml(line[i], w),
            }
            continue;
        }
        switch (line[i]) {
            '`' => {
                _ = try w.write("<code>");
                state.flags.is_code = true;
            },
            '"' => {
                if (state.flags.is_img) {
                    _ = try w.write("&quot;");
                } else {
                    _ = try w.write("\"");
                }
            },
            '*' => {
                if (i + 1 < line.len and line[i + 1] == '*') {
                    i += 1;
                    if (state.flags.is_strong) {
                        _ = try w.write("</strong>");
                    } else {
                        _ = try w.write("<strong>");
                    }
                    state.flags.is_strong = !state.flags.is_strong;
                } else {
                    if (state.flags.is_em) {
                        _ = try w.write("</em>");
                    } else {
                        _ = try w.write("<em>");
                    }
                    state.flags.is_em = !state.flags.is_em;
                }
            },
            '[' => {
                if (i + 1 < line.len and line[i + 1] == '^') {
                    i += 1;
                    ref_index = i + 1;
                    state.flags.is_footnote_citation = true;
                    _ = try w.write("<sup class=\"footnote-ref\"><a href=\"#fn");
                } else {
                    state.flags.is_link = true;
                    ref_index = i;
                    _ = try w.write("<a href=\"");
                    i = i + std.mem.indexOf(u8, line[i..], "](").? + 1;
                }
            },
            ')' => {
                if (state.flags.is_link) {
                    const new_ref_index = i;
                    i = ref_index.?;
                    ref_index = new_ref_index;
                    _ = try w.write("\">");
                } else if (state.flags.is_img) {
                    _ = try w.write("\" />");
                    state.flags.is_img = false;
                } else {
                    _ = try w.write(")");
                }
            },
            ']' => {
                if (state.flags.is_link) {
                    _ = try w.write("</a>");
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
                } else if (state.flags.is_img) {
                    std.debug.assert(line[i + 1] == '(');
                    i += 1;
                    _ = try w.write("\" src=\"");
                } else {
                    _ = try w.write("]");
                }
            },
            '!' => {
                if (i + 1 < line.len and line[i + 1] == '[') {
                    state.flags.is_img = true;
                    i += 1;
                    _ = try w.write("<img alt=\"");
                } else {
                    _ = try w.write("!");
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
        try w.print(" <a href=\"#fnref{d}", .{fn_key});
        if (j > 0) {
            try w.print(":{d}", .{j});
        }
        _ = try w.write("\" class=\"footnote-backref\">↩︎</a>");
    }
    _ = try w.write("</p></li>\n");
}

fn processHeading(level: u3, line: []u8, w: *Writer, state: *ast.BlockState) ProcessInlinesError!void {
    _ = try w.print("<h{d}>", .{level});
    try processInlines(line[level + 1 ..], w, state);
    _ = try w.print("</h{d}>\n", .{level});
}

fn closeBlocks(w: *Writer, state: *ast.BlockState, depth: usize) Writer.Error!void {
    state.resetFlags();
    while (state.len > depth) : ({
        state.items[state.len - 1] = null;
        state.len -= 1;
    }) switch (state.items[state.len - 1].?) {
        .block_quote => _ = try w.write("</blockquote>\n"),
        .unordered_list => _ = try w.write("</li>\n</ul>\n"),
        .ordered_list => _ = try w.write("</li>\n</ol>\n"),
        .paragraph => _ = try w.write("</p>\n"),
        .paragraph_hidden, .html_block => {},
        .code_block => _ = try w.write("</code></pre>\n"),
        .footnote_reference => _ = try w.write("</ol>\n</section>\n"),
        .table => _ = try w.write("</tbody>\n</table>\n"),
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
                if (std.mem.startsWith(u8, line, "> ")) {
                    line = line[2..];
                } else {
                    try closeBlocks(w, state, depth);
                }
            },
            .unordered_list => {
                if (std.mem.startsWith(u8, line, "  ")) {
                    line = line[2..];
                } else if (std.mem.startsWith(u8, line, "* ")) {
                    try closeBlocks(w, state, depth + 1);
                    _ = try w.write("</li>\n<li>");
                    line = line[2..];
                } else {
                    try closeBlocks(w, state, depth);
                }
            },
            .ordered_list => {
                if (std.mem.startsWith(u8, line, "   ")) {
                    line = line[3..];
                } else if (std.mem.startsWith(u8, line, "1. ")) {
                    try closeBlocks(w, state, depth + 1);
                    _ = try w.write("</li>\n<li>");
                    line = line[3..];
                } else {
                    try closeBlocks(w, state, depth);
                }
            },
            .paragraph, .paragraph_hidden => {
                if (line.len == 0) {
                    try closeBlocks(w, state, depth);
                } else {
                    _ = try w.write("\n"); // lazy continuation
                    try processInlines(line, w, state);
                }
                return;
            },
            .code_block => {
                if (std.mem.startsWith(u8, line, "```")) {
                    try closeBlocks(w, state, depth);
                } else {
                    for (line) |c| try printEscapedHtml(c, w);
                    _ = try w.write("\n");
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
                if (std.mem.startsWith(u8, line, "[^")) {
                    return processFootnoteReference(line, w, state);
                } else {
                    try closeBlocks(w, state, depth);
                }
            },
            .table => {
                // delimiter row
                if (std.mem.startsWith(u8, line, "| -")) {
                    @branchHint(.unlikely);
                    return;
                }
                if (std.mem.startsWith(u8, line, "| ")) {
                    _ = try w.write("<tr>\n");
                    while (line.len > 1) {
                        _ = try w.write("<td>");
                        line = line[2..];
                        const col_end = std.mem.indexOf(u8, line, " |").?;
                        try processInlines(line[0..col_end], w, state);
                        line = line[col_end + 1 ..];
                        _ = try w.write("</td>\n");
                    }
                    _ = try w.write("</tr>\n");
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

    if (std.mem.startsWith(u8, line, "> ")) { // block quote
        try state.push(.block_quote);
        _ = try w.write("<blockquote>\n");
        return processLine(line[2..], w, state, depth + 1);
    } else if (std.mem.startsWith(u8, line, "* ")) { // unordered list
        try state.push(.unordered_list);
        _ = try w.write("<ul>\n<li>");
        return processLine(line[2..], w, state, depth + 1);
    } else if (std.mem.startsWith(u8, line, "1. ")) { // ordered list
        try state.push(.ordered_list);
        _ = try w.write("<ol>\n<li>");
        return processLine(line[3..], w, state, depth + 1);
    } else if (std.mem.startsWith(u8, line, "```")) { // code block
        try state.push(.code_block);
        _ = try w.write("<pre><code");
        if (line[3..].len > 0) {
            try w.print(" class=\"language-{s}\"", .{line[3..]});
        }
        _ = try w.write(">");
        return;
    } else if (std.mem.startsWith(u8, line, "###### ")) { // heading 6
        return processHeading(6, line, w, state);
    } else if (std.mem.startsWith(u8, line, "##### ")) { // heading 5
        return processHeading(5, line, w, state);
    } else if (std.mem.startsWith(u8, line, "#### ")) { // heading 4
        return processHeading(4, line, w, state);
    } else if (std.mem.startsWith(u8, line, "### ")) { // heading 3
        return processHeading(3, line, w, state);
    } else if (std.mem.startsWith(u8, line, "## ")) { // heading 2
        return processHeading(2, line, w, state);
    } else if (std.mem.startsWith(u8, line, "# ")) { // heading 1
        return processHeading(1, line, w, state);
    } else if (std.mem.startsWith(u8, line, "[^")) { // footnote reference
        try state.push(.footnote_reference);
        _ = try w.write("<section class=\"footnotes\">\n<ol class=\"footnotes-list\">\n");
        return processFootnoteReference(line, w, state);
    } else if (std.mem.startsWith(u8, line, "| ")) { // table
        try state.push(.table);
        _ = try w.write("<table>\n<thead>\n<tr>\n");
        while (line.len > 1) {
            _ = try w.write("<th>");
            line = line[2..];
            const col_end = std.mem.indexOf(u8, line, " |").?;
            try processInlines(line[0..col_end], w, state);
            line = line[col_end + 1 ..];
            _ = try w.write("</th>\n");
        }
        _ = try w.write("</tr>\n</thead>\n<tbody>\n");
        return;
    } else if (std.mem.eql(u8, line, "---")) { // thematic break
        _ = try w.write("<hr />\n");
        return;
    } else if (line.len > 1 and line[0] == '<' and std.ascii.isAlphabetic(line[1])) { // HTML block
        try state.push(.html_block);
        return processLine(line, w, state, depth);
    } else { // paragraph
        if (state.len == 0) {
            try state.push(.paragraph);
            _ = try w.write("<p>");
        } else {
            switch (state.items[state.len - 1].?) {
                .unordered_list,
                .ordered_list,
                => try state.push(.paragraph_hidden),
                .paragraph, .paragraph_hidden => unreachable,
                else => {
                    try state.push(.paragraph);
                    _ = try w.write("<p>");
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
