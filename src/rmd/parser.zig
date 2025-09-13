const std = @import("std");
const ast = @import("./ast.zig");
const th = @import("./test_helpers.zig");

const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

const ParserError = Reader.DelimiterError || Allocator.Error;

fn appendHeadingBlock(allocator: Allocator, block: *ast.Block, line: []u8, level: u3) ParserError!void {
    var heading = try ast.Block.init(allocator, .heading);
    for (line[level + 1 ..]) |c| try heading.pending_inlines.?.append(allocator, c);
    heading.level = level;
    heading.open = false;
    try block.content.?.append(allocator, heading);
}

fn closeChildBlocks(block: *ast.Block) void {
    switch (block.tag) {
        .document, .code_block, .block_quote => {
            for (block.content.?.items) |*child| {
                child.open = false;
                closeChildBlocks(child);
            }
        },
        else => {},
    }
}

/// Recursively update a block and its descendants based on the
/// provided input line.
fn parseBlock(
    allocator: Allocator,
    line: []u8,
    block: *ast.Block,
) ParserError!void {
    var content = &block.content.?;
    const last_child = if (content.items.len > 0) &content.items[content.items.len - 1] else null;

    const is_open_code_block = last_child != null and last_child.?.tag == .code_block and last_child.?.open;

    if (line.len == 0 and !is_open_code_block) { // blank line and not literal content
        closeChildBlocks(block);
        return;
    }

    // open blocks
    if (last_child) |child| if (child.open) {
        switch (child.tag) {
            .document,
            .thematic_break,
            .heading,
            => unreachable,
            .paragraph => {
                try child.pending_inlines.?.append(allocator, '\n');
                for (line) |c| {
                    try child.pending_inlines.?.append(allocator, c);
                }
            },
            .code_block => {
                if (line.len >= 3 and std.mem.eql(u8, line[0..3], "```")) { // code block
                    child.open = false;
                } else {
                    for (line) |c| {
                        switch (c) {
                            '>' => try child.pending_inlines.?.appendSlice(allocator, "&gt;"),
                            '<' => try child.pending_inlines.?.appendSlice(allocator, "&lt;"),
                            '&' => try child.pending_inlines.?.appendSlice(allocator, "&amp;"),
                            else => try child.pending_inlines.?.append(allocator, c),
                        }
                    }
                    try child.pending_inlines.?.append(allocator, '\n');
                }
            },
            .block_quote => {
                const inner_line =
                    if (line.len > 1 and line[0] == '>' and line[1] == ' ')
                        line[2..]
                    else
                        line;
                try parseBlock(allocator, inner_line, child);
            },
        }
        return;
    };

    // new blocks
    if (line.len >= 3 and std.mem.eql(u8, line[0..3], "---")) { // thematic break
        var thematic_break = try ast.Block.init(allocator, .thematic_break);
        thematic_break.open = false;
        try content.append(allocator, thematic_break);
    } else if (line.len > 1 and std.mem.eql(u8, line[0..2], "# ")) { // heading 1
        try appendHeadingBlock(allocator, block, line, 1);
    } else if (line.len > 2 and std.mem.eql(u8, line[0..3], "## ")) { // heading 2
        try appendHeadingBlock(allocator, block, line, 2);
    } else if (line.len > 3 and std.mem.eql(u8, line[0..4], "### ")) { // heading 3
        try appendHeadingBlock(allocator, block, line, 3);
    } else if (line.len > 4 and std.mem.eql(u8, line[0..5], "#### ")) { // heading 4
        try appendHeadingBlock(allocator, block, line, 4);
    } else if (line.len > 5 and std.mem.eql(u8, line[0..6], "##### ")) { // heading 5
        try appendHeadingBlock(allocator, block, line, 5);
    } else if (line.len > 6 and std.mem.eql(u8, line[0..7], "###### ")) { // heading 6
        try appendHeadingBlock(allocator, block, line, 6);
    } else if (line.len >= 3 and std.mem.eql(u8, line[0..3], "```")) { // code block
        const code_block = try ast.Block.init(allocator, .code_block);
        try content.append(allocator, code_block);
    } else if (line[0] == '>' and (line.len == 1 or line[1] == ' ')) { // blockquote
        var block_quote = try ast.Block.init(allocator, .block_quote);
        const inner_line = if (line.len == 1) line[1..] else line[2..];
        try parseBlock(allocator, inner_line, &block_quote);
        try content.append(allocator, block_quote);
    } else { // paragraph
        var para = try ast.Block.init(allocator, .paragraph);
        for (line) |c| {
            try para.pending_inlines.?.append(allocator, c);
        }
        try content.append(allocator, para);
    }
}

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
        @branchHint(.cold); // stop using Windows please!
        return result[0 .. result.len - 2];
    }

    return result[0 .. result.len - 1];
}

/// Construct a block document from the input reader and write it into
/// the provided document pointer.
pub fn parseDocument(
    allocator: Allocator,
    reader: *Reader,
    document: *ast.Block,
) ParserError!void {
    while (takeNewlineExclusive(reader)) |line| {
        try parseBlock(allocator, line, document);
    } else |err| switch (err) {
        Reader.DelimiterError.EndOfStream => {}, // end of input
        else => return err,
    }
}

test "block closing and opening" {
    try th.expectParseRMD(
        \\> test
        \\lazy continuation
        \\
        \\>
        \\> para 1
        \\> 
        \\> para 2
    ,
        \\<blockquote>
        \\<p>test
        \\lazy continuation</p>
        \\</blockquote>
        \\<blockquote>
        \\<p>para 1</p>
        \\<p>para 2</p>
        \\</blockquote>
    );
}

test "blockquote empty" {
    try th.expectParseRMD(
        \\>
    ,
        \\<blockquote>
        \\</blockquote>
    );
}

test "blockquote empty with space" {
    try th.expectParseRMD(
        \\> 
    ,
        \\<blockquote>
        \\</blockquote>
    );
}

test "blockquote single line" {
    try th.expectParseRMD(
        \\> This is a block quote.
    ,
        \\<blockquote>
        \\<p>This is a block quote.</p>
        \\</blockquote>
    );
}

test "blockquote lazy continuation" {
    try th.expectParseRMD(
        \\> Hello,
        \\ world!
    ,
        \\<blockquote>
        \\<p>Hello,
        \\ world!</p>
        \\</blockquote>
    );
}
