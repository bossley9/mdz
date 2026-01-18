const std = @import("std");
const ast = @import("./ast.zig");
const slugify = @import("../slugify/slugify.zig");

const Io = std.Io;

const GenericMDZError = error{ InvalidMDZSyntax, UnreachableMDZCode };

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

fn printEscapedHtml(c: u8, w: *Io.Writer) Io.Writer.Error!usize {
    return switch (c) {
        '>' => w.write("&gt;"),
        '<' => w.write("&lt;"),
        '&' => w.write("&amp;"),
        else => w.write(&.{c}),
    };
}

const ProcessInlinesError = Io.Writer.Error || std.fmt.ParseIntError || std.fmt.BufPrintError || GenericMDZError;

fn processInlines(line: []u8, w: *Io.Writer, state: *ast.BlockState) ProcessInlinesError!usize {
    var len: usize = 0;
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
                        len += try printEscapedHtml(line[i], w);
                    }
                },
                '`' => {
                    len += try w.write("</code>");
                    state.flags.is_code = false;
                },
                else => len += try printEscapedHtml(line[i], w),
            }
            continue;
        }
        switch (line[i]) {
            '`' => {
                len += try w.write("<code>");
                state.flags.is_code = true;
            },
            '"' => {
                if (state.flags.is_img) {
                    len += try w.write("&quot;");
                } else {
                    len += try w.write("\"");
                }
            },
            '*' => {
                if (i + 1 < line.len and line[i + 1] == '*') {
                    i += 1;
                    len += try w.write(if (state.flags.is_strong)
                        "</strong>"
                    else
                        "<strong>");
                    state.flags.is_strong = !state.flags.is_strong;
                } else {
                    len += try w.write(if (state.flags.is_em)
                        "</em>"
                    else
                        "<em>");
                    state.flags.is_em = !state.flags.is_em;
                }
            },
            '~' => {
                if (std.mem.startsWith(u8, line[i..], "~~")) {
                    i += 1;
                    len += try w.write(if (state.flags.is_strike)
                        "</s>"
                    else
                        "<s>");
                    state.flags.is_strike = !state.flags.is_strike;
                } else {
                    len += try w.write("~");
                }
            },
            '-' => {
                if (std.mem.startsWith(u8, line[i..], "--")) {
                    i += 1;
                    len += try w.write(if (state.flags.is_del)
                        "</del>"
                    else
                        "<del>");
                    state.flags.is_del = !state.flags.is_del;
                } else {
                    len += try w.write("-");
                }
            },
            '+' => {
                if (std.mem.startsWith(u8, line[i..], "++")) {
                    i += 1;
                    len += try w.write(if (state.flags.is_ins)
                        "</ins>"
                    else
                        "<ins>");
                    state.flags.is_ins = !state.flags.is_ins;
                } else {
                    len += try w.write("+");
                }
            },
            '=' => {
                if (std.mem.startsWith(u8, line[i..], "==")) {
                    i += 1;
                    len += try w.write(if (state.flags.is_mark)
                        "</mark>"
                    else
                        "<mark>");
                    state.flags.is_mark = !state.flags.is_mark;
                } else {
                    len += try w.write("=");
                }
            },
            '[' => {
                if (i + 1 < line.len and line[i + 1] == '^') {
                    i += 1;
                    ref_index = i + 1;
                    state.flags.is_footnote_citation = true;
                    len += try w.write("<sup class=\"footnote-ref\"><a href=\"#fn");
                } else {
                    state.flags.is_link = true;
                    ref_index = i;
                    len += try w.write("<a href=\"");
                    i = i + (std.mem.indexOf(u8, line[i..], "](") orelse return error.InvalidMDZSyntax) + 1;
                }
            },
            ')' => {
                if (state.flags.is_link) {
                    const new_ref_index = i;
                    i = ref_index orelse return error.InvalidMDZSyntax;
                    ref_index = new_ref_index;
                    len += try w.write("\">");
                } else if (state.flags.is_img) {
                    len += try w.write("\" />");
                    state.flags.is_img = false;
                } else {
                    len += try w.write(")");
                }
            },
            ']' => {
                if (state.flags.is_link) {
                    len += try w.write("</a>");
                    i = ref_index orelse return error.InvalidMDZSyntax;
                    state.flags.is_link = false;
                    ref_index = null;
                } else if (state.flags.is_footnote_citation) {
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
                    state.flags.is_footnote_citation = false;
                    ref_index = null;
                } else if (state.flags.is_img) {
                    std.debug.assert(line[i + 1] == '(');
                    i += 1;
                    len += try w.write("\" src=\"");
                } else {
                    len += try w.write("]");
                }
            },
            '!' => {
                if (i + 1 < line.len and line[i + 1] == '[') {
                    state.flags.is_img = true;
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
    state.resetFlags();
    while (state.len > depth) : ({
        state.items[state.len - 1] = .nil;
        state.len -= 1;
    }) switch (state.items[state.len - 1]) {
        .nil => return GenericMDZError.UnreachableMDZCode,
        .block_quote => len += try w.write("</blockquote>\n"),
        .unordered_list => len += try w.write("</li>\n</ul>\n"),
        .ordered_list => len += try w.write("</li>\n</ol>\n"),
        .paragraph => len += try w.write("</p>\n"),
        .paragraph_hidden, .html_block => {},
        .code_block => len += try w.write("</code></pre>\n"),
        .footnote_reference => len += try w.write("</ol>\n</section>\n"),
        .table => len += try w.write("</tbody>\n</table>\n"),
    };
    return len;
}

const ProcessLineError = Io.Writer.Error || ast.StackError || ProcessInlinesError || GenericMDZError;

fn processLine(starting_line: []u8, w: *Io.Writer, state: *ast.BlockState, starting_depth: usize) ProcessLineError!usize {
    var depth = starting_depth;
    var line = starting_line;
    var len: usize = 0;

    //
    // validate existing blocks
    //

    while (depth < state.len) : (depth += 1) {
        switch (state.items[depth]) {
            .nil => return GenericMDZError.UnreachableMDZCode,
            .block_quote => {
                if (std.mem.startsWith(u8, line, "> ")) {
                    line = line[2..];
                } else {
                    len += try closeBlocks(w, state, depth);
                }
            },
            .unordered_list => {
                if (std.mem.startsWith(u8, line, "  ")) {
                    line = line[2..];
                } else if (std.mem.startsWith(u8, line, "* ")) {
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
                } else if (std.mem.startsWith(u8, line, "1. ")) {
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
                if (std.mem.startsWith(u8, line, "```")) {
                    len += try closeBlocks(w, state, depth);
                } else {
                    for (line) |c| len += try printEscapedHtml(c, w);
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
                if (std.mem.startsWith(u8, line, "[^")) {
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
                if (std.mem.startsWith(u8, line, "| ")) {
                    len += try w.write("<tr>\n");
                    while (line.len > 1) {
                        len += try w.write("<td>");
                        line = line[2..];
                        const col_end = std.mem.indexOf(u8, line, " |") orelse return error.InvalidMDZSyntax;
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

    if (std.mem.startsWith(u8, line, "> ")) { // block quote
        try state.push(.block_quote);
        len += try w.write("<blockquote>\n");
        return len + try processLine(line[2..], w, state, depth + 1);
    } else if (std.mem.startsWith(u8, line, "* ")) { // unordered list
        try state.push(.unordered_list);
        len += try w.write("<ul>\n<li>");
        return len + try processLine(line[2..], w, state, depth + 1);
    } else if (std.mem.startsWith(u8, line, "1. ")) { // ordered list
        try state.push(.ordered_list);
        len += try w.write("<ol>\n<li>");
        return len + try processLine(line[3..], w, state, depth + 1);
    } else if (std.mem.startsWith(u8, line, "```")) { // code block
        try state.push(.code_block);
        len += try w.write("<pre><code");
        const lang = line[3..];
        if (lang.len > 0 and !std.mem.eql(u8, lang, "plaintext")) {
            var buf: [64]u8 = undefined;
            const fmt = try std.fmt.bufPrint(&buf, " class=\"language-{s}\"", .{lang});
            len += try w.write(fmt);
        }
        return len + try w.write(">");
    } else if (std.mem.startsWith(u8, line, "###### ")) { // heading 6
        return len + try processHeading(6, line, w, state);
    } else if (std.mem.startsWith(u8, line, "##### ")) { // heading 5
        return len + try processHeading(5, line, w, state);
    } else if (std.mem.startsWith(u8, line, "#### ")) { // heading 4
        return len + try processHeading(4, line, w, state);
    } else if (std.mem.startsWith(u8, line, "### ")) { // heading 3
        return len + try processHeading(3, line, w, state);
    } else if (std.mem.startsWith(u8, line, "## ")) { // heading 2
        return len + try processHeading(2, line, w, state);
    } else if (std.mem.startsWith(u8, line, "# ")) { // heading 1
        return len + try processHeading(1, line, w, state);
    } else if (std.mem.startsWith(u8, line, "[^")) { // footnote reference
        try state.push(.footnote_reference);
        len += try w.write("<section class=\"footnotes\">\n<ol class=\"footnotes-list\">\n");
        return len + try processFootnoteReference(line, w, state);
    } else if (std.mem.startsWith(u8, line, "| ")) { // table
        try state.push(.table);
        len += try w.write("<table>\n<thead>\n<tr>\n");
        while (line.len > 1) {
            len += try w.write("<th>");
            line = line[2..];
            const col_end = std.mem.indexOf(u8, line, " |") orelse return error.InvalidMDZSyntax;
            len += try processInlines(line[0..col_end], w, state);
            line = line[col_end + 1 ..];
            len += try w.write("</th>\n");
        }
        return len + try w.write("</tr>\n</thead>\n<tbody>\n");
    } else if (std.mem.eql(u8, line, "---")) { // thematic break
        return len + try w.write("<hr />\n");
    } else if (line.len > 1 and line[0] == '<' and std.ascii.isAlphabetic(line[1])) { // HTML block
        switch (state.getLastBlock()) {
            .ordered_list, .unordered_list => {},
            else => {
                try state.push(.html_block);
                return len + try processLine(line, w, state, depth);
            },
        }
    } else { // paragraph
        switch (state.getLastBlock()) {
            .unordered_list,
            .ordered_list,
            => try state.push(.paragraph_hidden),
            .paragraph, .paragraph_hidden => return GenericMDZError.UnreachableMDZCode,
            else => {
                try state.push(.paragraph);
                len += try w.write("<p>");
            },
        }
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
    var state = ast.BlockState.init();
    var len: usize = 0;

    while (takeNewlineExclusive(r)) |line| {
        len += try processLine(line, w, &state, 0);
    } else |e| switch (e) {
        Io.Reader.DelimiterError.EndOfStream => {}, // end of input
        Io.Reader.DelimiterError.ReadFailed,
        Io.Reader.DelimiterError.StreamTooLong,
        => |err| return err,
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
