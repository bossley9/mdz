const std = @import("std");
const ast = @import("./ast.zig");
const highlight = @import("./highlight.zig");
const slugify = @import("../slugify/slugify.zig");

const Io = std.Io;

const GenericMDZError = error{ InvalidMDZSyntax, OutOfMemory };

/// Custom implementation of `Io.Reader.takeDelimiterExclusive` to
/// account for different line endings (LF/CRLF) and optional EOF LF.
fn takeNewlineExclusive(r: *Io.Reader) Io.Reader.DelimiterError![]u8 {
    const result = r.peekDelimiterInclusive('\n') catch |err| switch (err) {
        Io.Reader.DelimiterError.EndOfStream, Io.Reader.DelimiterError.StreamTooLong => {
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

pub fn printEscapedHtml(c: u8, w: *Io.Writer) Io.Writer.Error!usize {
    return switch (c) {
        '>' => w.write("&gt;"),
        '<' => w.write("&lt;"),
        '&' => w.write("&amp;"),
        else => {
            try w.writeByte(c);
            return 1;
        },
    };
}

const ProcessInlinesError =
    Io.Writer.Error ||
    std.fmt.ParseIntError ||
    std.fmt.BufPrintError ||
    GenericMDZError;

fn processInlines(line: []u8, w: *Io.Writer, state: *ast.BlockState) ProcessInlinesError!usize {
    var len: usize = 0;
    var ref_index: ?usize = null;
    var i: usize = 0;
    while (i < line.len) : (i += 1) {
        if (state.flags.contains(.is_code)) {
            @branchHint(.unlikely);
            switch (line[i]) {
                '\\' => {
                    i += 1;
                    if (i < line.len) {
                        @branchHint(.likely);
                        len += try printEscapedHtml(line[i], w);
                    }
                },
                '`' => {
                    len += try w.write("</code>");
                    state.flags.remove(.is_code);
                },
                else => len += try printEscapedHtml(line[i], w),
            }
            continue;
        }
        switch (line[i]) {
            '`' => {
                len += try w.write("<code>");
                state.flags.insert(.is_code);
            },
            '"' => len += try w.write(if (state.flags.contains(.is_img)) "&quot;" else "\""),
            '*' => {
                if (state.flags.contains(.is_em) and state.flags.contains(.is_strong) and std.mem.startsWith(u8, line[i..], "***")) {
                    i += 2;
                    len += try w.write("</em></strong>");
                    state.flags.remove(.is_strong);
                    state.flags.remove(.is_em);
                } else if (std.mem.startsWith(u8, line[i..], "**")) {
                    i += 1;
                    len += try w.write(if (state.flags.contains(.is_strong))
                        "</strong>"
                    else
                        "<strong>");
                    state.flags.toggle(.is_strong);
                } else {
                    len += try w.write(if (state.flags.contains(.is_em))
                        "</em>"
                    else
                        "<em>");
                    state.flags.toggle(.is_em);
                }
            },
            '~' => {
                if (std.mem.startsWith(u8, line[i..], "~~")) {
                    i += 1;
                    len += try w.write(if (state.flags.contains(.is_strike))
                        "</s>"
                    else
                        "<s>");
                    state.flags.toggle(.is_strike);
                } else {
                    len += try w.write("~");
                }
            },
            '-' => {
                if (std.mem.startsWith(u8, line[i..], "--")) {
                    i += 1;
                    len += try w.write(if (state.flags.contains(.is_del))
                        "</del>"
                    else
                        "<del>");
                    state.flags.toggle(.is_del);
                } else {
                    len += try w.write("-");
                }
            },
            '+' => {
                if (std.mem.startsWith(u8, line[i..], "++")) {
                    i += 1;
                    len += try w.write(if (state.flags.contains(.is_ins))
                        "</ins>"
                    else
                        "<ins>");
                    state.flags.toggle(.is_ins);
                } else {
                    len += try w.write("+");
                }
            },
            '=' => {
                if (std.mem.startsWith(u8, line[i..], "==")) {
                    i += 1;
                    len += try w.write(if (state.flags.contains(.is_mark))
                        "</mark>"
                    else
                        "<mark>");
                    state.flags.toggle(.is_mark);
                } else {
                    len += try w.write("=");
                }
            },
            '[' => {
                if (i + 1 < line.len and line[i + 1] == '^') {
                    i += 1;
                    ref_index = i + 1;
                    state.flags.insert(.is_footnote_citation);
                    len += try w.write("<sup class=\"footnote-ref\"><a href=\"#fn");
                } else {
                    state.flags.insert(.is_link);
                    ref_index = i;
                    len += try w.write("<a href=\"");
                    i = i + (std.mem.find(u8, line[i..], "](") orelse return error.InvalidMDZSyntax) + 1;
                }
            },
            ')' => {
                if (state.flags.contains(.is_link)) {
                    const new_ref_index = i;
                    i = ref_index orelse return error.InvalidMDZSyntax;
                    ref_index = new_ref_index;
                    len += try w.write("\">");
                } else if (state.flags.contains(.is_img)) {
                    len += try w.write("\" />");
                    state.flags.remove(.is_img);
                } else {
                    len += try w.write(")");
                }
            },
            ']' => {
                if (state.flags.contains(.is_link)) {
                    len += try w.write("</a>");
                    i = ref_index orelse return error.InvalidMDZSyntax;
                    state.flags.remove(.is_link);
                    ref_index = null;
                } else if (state.flags.contains(.is_footnote_citation)) {
                    const fn_key = try std.fmt.parseInt(u8, line[(ref_index orelse return error.InvalidMDZSyntax)..i], 10);
                    const fn_num = state.footnotes[fn_key];

                    var buf: [48]u8 = undefined;
                    if (fn_num > 0) {
                        const fmt = try std.fmt.bufPrint(
                            &buf,
                            "\" id=\"fnref{d}:{d}\">[{d}:{d}]</a></sup>",
                            .{ fn_key, fn_num, fn_key, fn_num },
                        );
                        len += try w.write(fmt);
                    } else {
                        const fmt = try std.fmt.bufPrint(&buf, "\" id=\"fnref{d}\">[{d}]</a></sup>", .{ fn_key, fn_key });
                        len += try w.write(fmt);
                    }
                    state.footnotes[fn_key] += 1;
                    state.flags.remove(.is_footnote_citation);
                    ref_index = null;
                } else if (state.flags.contains(.is_img)) {
                    std.debug.assert(line[i + 1] == '(');
                    i += 1;
                    len += try w.write("\" src=\"");
                } else {
                    len += try w.write("]");
                }
            },
            '!' => {
                if (i + 1 < line.len and line[i + 1] == '[') {
                    state.flags.insert(.is_img);
                    i += 1;
                    len += try w.write("<img alt=\"");
                } else {
                    len += try w.write("!");
                }
            },
            '\\' => {
                i += 1;
                if (i < line.len) {
                    @branchHint(.likely);
                    len += try printEscapedHtml(line[i], w);
                }
            },
            else => len += try w.write(&.{line[i]}),
        }
    }
    return len;
}

fn processFootnoteReference(line: []u8, w: *Io.Writer, state: *ast.BlockState) ProcessInlinesError!usize {
    std.debug.assert(std.mem.eql(u8, line[0..2], "[^"));
    var len: usize = 0;
    var i: usize = 2;
    while (i < line.len and line[i] != ']') : (i += 1) {}
    const fn_key = try std.fmt.parseInt(u8, line[2..i], 10);
    var buf: [64]u8 = undefined;
    const fmt = try std.fmt.bufPrint(&buf, "<li id=\"fn{d}\" class=\"footnote-item\"><p>", .{fn_key});
    len += try w.write(fmt);
    len += try processInlines(line[i + 3 ..], w, state);
    var j: usize = 0;
    while (j < state.footnotes[fn_key]) : (j += 1) {
        const inner_fmt = try std.fmt.bufPrint(&buf, " <a href=\"#fnref{d}", .{fn_key});
        len += try w.write(inner_fmt);
        if (j > 0) {
            const num_fmt = try std.fmt.bufPrint(&buf, ":{d}", .{j});
            len += try w.write(num_fmt);
        }
        len += try w.write("\" class=\"footnote-backref\">↩︎</a>");
    }
    len += try w.write("</p></li>\n");
    return len;
}

fn processHeading(level: u3, line: []u8, w: *Io.Writer, state: *ast.BlockState) ProcessInlinesError!usize {
    var len: usize = 0;
    const content = line[level + 1 ..];
    var buf: [256]u8 = undefined;

    if (level == 1) {
        @branchHint(.unlikely);
        const start_fmt = try std.fmt.bufPrint(&buf, "<h{d}>", .{level});
        len += try w.write(start_fmt);
        len += try processInlines(content, w, state);
        const end_fmt = try std.fmt.bufPrint(&buf, "</h{d}>\n", .{level});
        len += try w.write(end_fmt);
    } else {
        var id_buf: [128]u8 = undefined;
        const id_len = slugify.slugify(content, &id_buf);
        const id = id_buf[0..id_len];
        const start_fmt = try std.fmt.bufPrint(&buf, "<h{d} id=\"{s}\"><a href=\"#{s}\">", .{ level, id, id });
        len += try w.write(start_fmt);
        len += try processInlines(content, w, state);
        const end_fmt = try std.fmt.bufPrint(&buf, "</a></h{d}>\n", .{level});
        len += try w.write(end_fmt);
    }
    return len;
}

const CloseBlocksError = Io.Writer.Error || GenericMDZError;
fn closeBlocks(w: *Io.Writer, state: *ast.BlockState, depth: usize) CloseBlocksError!usize {
    var len: usize = 0;
    state.flags = .init(.{});
    while (state.items.items.len > depth) {
        const str = switch (state.items.pop().?) {
            .block_quote => "</blockquote>\n",
            .aside => "</aside>\n",
            .unordered_list => "</li>\n</ul>\n",
            .ordered_list => "</li>\n</ol>\n",
            .paragraph => "</p>\n",
            .paragraph_hidden, .html_block => "",
            .code_block => "</code></pre>\n",
            .pre_block => "</pre>\n",
            .footnote_reference => "</ol>\n</section>\n",
            .table => "</tbody>\n</table>\n",
        };
        len += try w.write(str);
    }
    return len;
}

/// Line prefixes only 2-3 characters long
const LinePrefix = enum {
    @"> ",
    @"a> ",
    @"* ",
    @"1. ",
    @"```",
    @"===",
    @"# ",
    @"## ",
    @"[^",
    @"| ",
    @"---",
    nomatch,
};

const ProcessLineError =
    Io.Writer.Error ||
    ProcessInlinesError ||
    GenericMDZError;

fn processLine(starting_line: []u8, w: *Io.Writer, state: *ast.BlockState, starting_depth: usize) ProcessLineError!usize {
    var depth = starting_depth;
    var line = starting_line;
    var len: usize = 0;

    //
    // validate existing blocks
    //

    while (depth < state.items.items.len) : (depth += 1) {
        switch (state.items.items[depth]) {
            .block_quote => {
                if (std.mem.startsWith(u8, line, @tagName(LinePrefix.@"> "))) {
                    line = line[2..];
                } else {
                    len += try closeBlocks(w, state, depth);
                }
            },
            .aside => {
                if (std.mem.startsWith(u8, line, @tagName(LinePrefix.@"a> "))) {
                    line = line[3..];
                } else {
                    len += try closeBlocks(w, state, depth);
                }
            },
            .unordered_list => {
                if (std.mem.startsWith(u8, line, "  ")) {
                    line = line[2..];
                } else if (std.mem.startsWith(u8, line, @tagName(LinePrefix.@"* "))) {
                    len += try closeBlocks(w, state, depth + 1);
                    len += try w.write("</li>\n<li>");
                    line = line[2..];
                } else {
                    len += try closeBlocks(w, state, depth);
                }
            },
            .ordered_list => {
                if (std.mem.startsWith(u8, line, "   ")) {
                    line = line[3..];
                } else if (std.mem.startsWith(u8, line, @tagName(LinePrefix.@"1. "))) {
                    len += try closeBlocks(w, state, depth + 1);
                    len += try w.write("</li>\n<li>");
                    line = line[3..];
                } else {
                    len += try closeBlocks(w, state, depth);
                }
            },
            .paragraph, .paragraph_hidden => {
                if (line.len == 0) {
                    len += try closeBlocks(w, state, depth);
                } else {
                    len += try w.write("\n"); // lazy continuation
                    len += try processInlines(line, w, state);
                }
                return len;
            },
            .code_block => {
                if (std.mem.startsWith(u8, line, @tagName(LinePrefix.@"```"))) {
                    len += try closeBlocks(w, state, depth);
                } else {
                    len += try highlight.highlight_code_line(w, line, state.lang);
                }
                return len;
            },
            .pre_block => {
                if (std.mem.startsWith(u8, line, @tagName(LinePrefix.@"==="))) {
                    len += try closeBlocks(w, state, depth);
                } else {
                    len += try w.write(line);
                    len += try w.write("\n");
                }
                return len;
            },
            .html_block => {
                if (line.len == 0) {
                    len += try closeBlocks(w, state, depth);
                } else {
                    len += try w.write(std.mem.trim(u8, line, " "));
                    len += try w.write("\n");
                }
                return len;
            },
            .footnote_reference => {
                if (std.mem.startsWith(u8, line, @tagName(LinePrefix.@"[^"))) {
                    return len + try processFootnoteReference(line, w, state);
                } else {
                    len += try closeBlocks(w, state, depth);
                }
            },
            .table => {
                // delimiter row
                if (std.mem.startsWith(u8, line, "| -")) {
                    @branchHint(.unlikely);
                    return len;
                }
                if (std.mem.startsWith(u8, line, @tagName(LinePrefix.@"| "))) {
                    len += try w.write("<tr>\n");
                    while (line.len > 1) {
                        len += try w.write("<td>");
                        line = line[2..];
                        const col_end = std.mem.find(u8, line, " |") orelse return error.InvalidMDZSyntax;
                        len += try processInlines(line[0..col_end], w, state);
                        line = line[col_end + 1 ..];
                        len += try w.write("</td>\n");
                    }
                    return len + try w.write("</tr>\n");
                } else {
                    len += try closeBlocks(w, state, depth);
                }
            },
        }
    }

    //
    // close blocks for blank lines
    //

    if (line.len == 0) {
        return len + try closeBlocks(w, state, depth);
    }

    //
    // create new blocks
    //

    var line_prefix: LinePrefix = if (line.len >= 3)
        std.meta.stringToEnum(LinePrefix, line[0..3]) orelse .nomatch
    else
        .nomatch;

    if (line_prefix == .nomatch and line.len >= 2) {
        line_prefix = std.meta.stringToEnum(LinePrefix, line[0..2]) orelse .nomatch;
    }

    switch (line_prefix) {
        .@"> " => {
            try state.items.appendBounded(.block_quote);
            len += try w.write("<blockquote>\n");
            return len + try processLine(line[2..], w, state, depth + 1);
        },
        .@"a> " => {
            try state.items.appendBounded(.aside);
            len += try w.write("<aside>\n");
            return len + try processLine(line[3..], w, state, depth + 1);
        },
        .@"* " => {
            try state.items.appendBounded(.unordered_list);
            len += try w.write("<ul>\n<li>");
            return len + try processLine(line[2..], w, state, depth + 1);
        },
        .@"1. " => {
            try state.items.appendBounded(.ordered_list);
            len += try w.write("<ol>\n<li>");
            return len + try processLine(line[3..], w, state, depth + 1);
        },
        .@"```" => {
            try state.items.appendBounded(.code_block);
            len += try w.write("<pre><code");

            state.lang = std.meta.stringToEnum(ast.CodeLanguage, line[3..]) orelse .plaintext;

            if (state.lang != .plaintext) {
                const tag_name = @tagName(state.lang);
                try w.print(" class=\"language-{s}\"", .{tag_name});
                len += 18 + tag_name.len;
            }

            return len + try w.write(">");
        },
        .@"===" => {
            try state.items.appendBounded(.pre_block);
            return len + try w.write("<pre>");
        },
        .@"# " => return len + try processHeading(1, line, w, state),
        .@"## " => return len + try processHeading(2, line, w, state),
        .@"[^" => {
            try state.items.appendBounded(.footnote_reference);
            len += try w.write("<section class=\"footnotes\">\n<ol class=\"footnotes-list\">\n");
            return len + try processFootnoteReference(line, w, state);
        },
        .@"| " => {
            try state.items.appendBounded(.table);
            len += try w.write("<table>\n<thead>\n<tr>\n");
            while (line.len > 1) {
                len += try w.write("<th>");
                line = line[2..];
                const col_end = std.mem.find(u8, line, " |") orelse return error.InvalidMDZSyntax;
                len += try processInlines(line[0..col_end], w, state);
                line = line[col_end + 1 ..];
                len += try w.write("</th>\n");
            }
            return len + try w.write("</tr>\n</thead>\n<tbody>\n");
        },
        .@"---" => return len + try w.write("<hr />\n"),
        .nomatch => {
            if (std.mem.startsWith(u8, line, "#")) {
                @branchHint(.unlikely);
                if (std.mem.startsWith(u8, line, "###### ")) { // heading 6
                    return len + try processHeading(6, line, w, state);
                } else if (std.mem.startsWith(u8, line, "##### ")) { // heading 5
                    return len + try processHeading(5, line, w, state);
                } else if (std.mem.startsWith(u8, line, "#### ")) { // heading 4
                    return len + try processHeading(4, line, w, state);
                } else if (std.mem.startsWith(u8, line, "### ")) { // heading 3
                    return len + try processHeading(3, line, w, state);
                }
            }

            if (line.len > 1 and line[0] == '<' and switch (line[1]) {
                'A'...'Z', 'a'...'z', '/' => true,
                else => false,
            }) { // HTML block
                @branchHint(.unlikely);
                const block = state.items.getLastOrNull() orelse .paragraph; // any block to fall in else
                switch (block) {
                    .ordered_list, .unordered_list => {},
                    else => {
                        try state.items.appendBounded(.html_block);
                        return len + try processLine(line, w, state, depth);
                    },
                }
            } else { // paragraph
                const block = state.items.getLastOrNull() orelse .table; // arbitrary block to fall in else
                switch (block) {
                    .unordered_list,
                    .ordered_list,
                    => try state.items.appendBounded(.paragraph_hidden),
                    .paragraph, .paragraph_hidden => unreachable,
                    else => {
                        try state.items.appendBounded(.paragraph);
                        len += try w.write("<p>");
                    },
                }
            }
        },
    }

    //
    // process leaf blocks
    //

    return len + try processInlines(line, w, state);
}

pub const ParseMDZError = error{ ReadFailed, StreamTooLong } || ProcessLineError;

/// Given an MDZ input reader and an output writer, parse and write the
/// corresponding HTML string to the writer, then return the number of
/// bytes written.
pub fn parseMDZ(r: *Io.Reader, w: *Io.Writer) ParseMDZError!usize {
    var stack_buffer: [16]ast.Block = undefined;
    var state = ast.BlockState.init(&stack_buffer);
    var len: usize = 0;

    while (takeNewlineExclusive(r)) |line| {
        len += try processLine(line, w, &state, 0);
    } else |err| switch (err) {
        Io.Reader.DelimiterError.EndOfStream => {}, // end of input
        else => |e| return e,
    }
    len += try closeBlocks(w, &state, 0); // close remaining blocks

    try w.flush();
    return len;
}

fn fakeDrain(w: *Io.Writer, _: []const []const u8, _: usize) Io.Writer.Error!usize {
    w.end = 0;
    return 0;
}

test "does not attempt to undo buffer write when empty" {
    const expected = "<p>Hello</p>";
    var r = Io.Reader.fixed("Hello");
    var buf: [expected.len]u8 = undefined;
    var w: Io.Writer = .{
        .vtable = &.{ .drain = fakeDrain },
        .buffer = &buf,
    };
    _ = try parseMDZ(&r, &w);
    try std.testing.expect(true == true); // no integer overflow
}
