const std = @import("std");
const ast = @import("./djot/ast.zig");
const parser = @import("./djot/parser.zig");
const printer = @import("./djot/printer.zig");

const ParseDjotError = std.io.Reader.DelimiterError || std.mem.Allocator.Error || std.io.Writer.Error;

/// Given a Djot input reader and an output writer, parse and write the
/// corresponding HTML string to the writer, then return the number of
/// bytes written.
pub fn parseDjot(reader: *std.io.Reader, w: *std.io.Writer) ParseDjotError!usize {
    const allocator = std.heap.page_allocator;
    var document = try ast.Block.init(allocator, .document);
    defer {
        for (document.content.?.items) |*child| switch (child.*.tag) {
            .document => unreachable,
            .heading, .paragraph => {
                child.inlines.?.deinit(allocator);
            },
            .block_quote => {
                child.content.?.deinit(allocator);
            },
        };
        document.content.?.deinit(allocator);
    }

    try parser.parseDocument(allocator, reader, &document);

    try printer.printDocument(&document, w);
    if (w.end > 0) {
        w.undo(1); // remove final newline from printed output
    }

    try w.flush();
    return w.end;
}

/// Given a Djot input string address, parse and write the corresponding
/// HTML output string to memory, then return the length. An error is
/// returned as the string "error.message", where `message` represents
/// the error message.
export fn parseDjotWasm(input_addr: [*]u8, input_len: usize) usize {
    if (input_len == 0) {
        @branchHint(.cold);
        return 0;
    }

    const input = input_addr[0..input_len];
    var reader = std.io.Reader.fixed(input);

    var output: [std.wasm.page_size]u8 = undefined;
    var writer = std.io.Writer.fixed(&output);

    const len = parseDjot(&reader, &writer) catch |err| blk: {
        writer.print("{any}", .{err}) catch {};
        writer.flush() catch {};
        break :blk writer.end;
    };

    // write result to contiguous memory, overwriting input
    var i: usize = 0;
    while (i < len) : (i += 1) {
        input_addr[i] = output[i];
    }
    return len;
}
