const std = @import("std");
const ast = @import("./ast.zig");

const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

const ParserError = Reader.DelimiterError || Allocator.Error;

/// Update a block's inlines based on the provided input string.
fn parseInlines(
    allocator: Allocator,
    block: *ast.Block,
) ParserError!void {
    const str = block.inlines.?.items;

    var i: usize = 0;
    while (i < str.len) : (i += 1) {
        // always guarantee available child
        if (block.content.?.items.len == 0) {
            const text = try ast.Block.init(allocator, .text);
            try block.content.?.append(allocator, text);
        }
        var last_child = &block.content.?.items[block.content.?.items.len - 1];

        if (str[i] == '\\') { // escaped text
            i += 1;
            if (i < str.len) {
                switch (str[i]) {
                    '>' => try last_child.inlines.?.appendSlice(allocator, "&gt;"),
                    '<' => try last_child.inlines.?.appendSlice(allocator, "&lt;"),
                    '&' => try last_child.inlines.?.appendSlice(allocator, "&amp;"),
                    else => try last_child.inlines.?.append(allocator, str[i]),
                }
            }
        } else { // plain text
            try last_child.inlines.?.append(allocator, str[i]);
        }
    }
    block.inlines.?.clearAndFree(allocator);
    try closeChildBlocks(allocator, block);
}

fn appendHeadingBlock(allocator: Allocator, block: *ast.Block, line: []u8, level: u3) ParserError!void {
    var heading = try ast.Block.init(allocator, .heading);
    for (line[level + 1 ..]) |c| try heading.inlines.?.append(allocator, c);
    heading.level = level;
    heading.open = false;
    try parseInlines(allocator, &heading);
    try block.content.?.append(allocator, heading);
}

fn closeChildBlocks(allocator: Allocator, block: *ast.Block) ParserError!void {
    switch (block.tag) {
        .document, .paragraph, .block_quote => {
            for (block.content.?.items) |*child| {
                child.open = false;
                if (child.tag == .paragraph) {
                    try parseInlines(allocator, child);
                }
                try closeChildBlocks(allocator, child);
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
        try closeChildBlocks(allocator, block);
        return;
    }

    // open blocks
    if (last_child) |child| if (child.open) {
        switch (child.tag) {
            .document,
            .thematic_break,
            .heading,
            // inlines parsed separately
            .text,
            => unreachable,
            .paragraph => {
                try child.inlines.?.append(allocator, '\n');
                for (line) |c| {
                    try child.inlines.?.append(allocator, c);
                }
            },
            .code_block => {
                if (line.len >= 3 and std.mem.eql(u8, line[0..3], "```")) {
                    child.open = false;
                } else {
                    for (line) |c| {
                        switch (c) {
                            '>' => try child.inlines.?.appendSlice(allocator, "&gt;"),
                            '<' => try child.inlines.?.appendSlice(allocator, "&lt;"),
                            '&' => try child.inlines.?.appendSlice(allocator, "&amp;"),
                            else => try child.inlines.?.append(allocator, c),
                        }
                    }
                    try child.inlines.?.append(allocator, '\n');
                }
            },
            .html_block => {
                for (line) |c| {
                    try child.inlines.?.append(allocator, c);
                }
                try child.inlines.?.append(allocator, '\n');
            },
            .block_quote => {
                const inner_line =
                    if (line.len == 1 and line[0] == '>')
                        line[1..]
                    else if (line.len > 1 and line[0] == '>' and line[1] == ' ')
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
        var code_block = try ast.Block.init(allocator, .code_block);
        if (line.len > 3) {
            for (line[3..], 0..) |c, i| {
                if (i >= code_block.lang.len) break;
                code_block.lang[i] = c;
            }
        }
        try content.append(allocator, code_block);
    } else if (line[0] == '>' and (line.len == 1 or line[1] == ' ')) { // blockquote
        var block_quote = try ast.Block.init(allocator, .block_quote);
        const inner_line = if (line.len == 1) line[1..] else line[2..];
        try parseBlock(allocator, inner_line, &block_quote);
        try content.append(allocator, block_quote);
    } else if (line.len > 1 and line[0] == '<' and std.ascii.isAlphabetic(line[1])) { // HTML block
        var html_block = try ast.Block.init(allocator, .html_block);
        for (line) |c| {
            try html_block.inlines.?.append(allocator, c);
        }
        try html_block.inlines.?.append(allocator, '\n');
        try content.append(allocator, html_block);
    } else { // paragraph
        var para = try ast.Block.init(allocator, .paragraph);
        for (line) |c| {
            try para.inlines.?.append(allocator, c);
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
    try closeChildBlocks(allocator, document);
}
