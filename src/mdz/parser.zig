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

fn printEscapedChar(c: u8, w: *Writer) Writer.Error!void {
    switch (c) {
        '>' => try w.print("&gt;", .{}),
        '<' => try w.print("&lt;", .{}),
        '&' => try w.print("&amp;", .{}),
        else => try w.print("{c}", .{c}),
    }
}

fn closeBlocks(w: *Writer, stack: *ast.BlockStack) Writer.Error!void {
    while (ast.stackPop(stack)) |val| switch (val) {
        .nil => unreachable,
        .block_quote => {
            try w.print("</blockquote>\n", .{});
        },
        .paragraph => {
            try w.print("</p>\n", .{});
        },
    };
}

const ProcessLineError = Writer.Error || ast.StackError;

fn processLine(line: []u8, w: *Writer, stack: *ast.BlockStack) ProcessLineError!void {
    if (line.len == 0) {
        try closeBlocks(w, stack);
        return;
    }

    var inner_line = line;

    if (line.len > 1 and std.mem.eql(u8, line[0..2], "> ")) { // block quote
        try ast.stackPush(stack, .block_quote);
        try w.print("<blockquote>\n", .{});
        inner_line = line[2..];
    }

    if (stack.len == 0 or stack.items[stack.len - 1] != .paragraph) { // paragraph
        try ast.stackPush(stack, .paragraph);
        try w.print("<p>", .{});
    }

    var i: usize = 0;
    while (i < inner_line.len) : (i += 1) {
        switch (inner_line[i]) {
            '\\' => {
                i += 1;
                if (i < inner_line.len) {
                    @branchHint(.likely);
                    try printEscapedChar(inner_line[i], w);
                }
            },
            else => try w.print("{c}", .{inner_line[i]}),
        }
    }
}

pub const ProcessDocumentError = error{ ReadFailed, StreamTooLong, WriteFailed } || ast.StackError;

/// Read an MDZ document from a input reader and incrementally write
/// the output to writer.
pub fn processDocument(r: *Reader, w: *Writer) ProcessDocumentError!void {
    var stack = ast.BlockStack{
        .items = undefined,
        .len = 0,
    };
    @memset(&stack.items, ast.Block.nil);

    while (takeNewlineExclusive(r)) |line| {
        try processLine(line, w, &stack);
    } else |e| switch (e) {
        Reader.DelimiterError.EndOfStream => {}, // end of input
        Reader.DelimiterError.ReadFailed,
        Reader.DelimiterError.StreamTooLong,
        => |err| return err,
    }
    try closeBlocks(w, &stack); // close remaining blocks
}
