const std = @import("std");
const ast = @import("./djot/ast.zig");
const parser = @import("./djot/parser.zig");
const printer = @import("./djot/printer.zig");
const th = @import("./djot/test_helpers.zig");

const ParseDjotError = std.mem.Allocator.Error || std.io.Writer.Error;

/// Given a Djot input string and an output writer, parse and write the
/// corresponding HTML string to the writer, then return the number of
/// bytes written.
pub fn parseDjot(input: []u8, w: *std.io.Writer) ParseDjotError!usize {
    const allocator = std.heap.page_allocator;
    var document = ast.Document{
        .openStack = try std.ArrayList(ast.Block).initCapacity(allocator, 12),
        .content = try std.ArrayList(ast.Block).initCapacity(allocator, 0),
    };
    defer {
        document.openStack.deinit(allocator);
        for (document.content.items) |child| switch (child) {
            .paragraph => {},
            .block_quote => {
                var content = child.block_quote.content;
                content.deinit(allocator);
            },
        };
        document.content.deinit(allocator);
    }

    try parser.parseDocument(allocator, input, &document);

    try printer.printDocument(&document, input, w);

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
    var output: [1024 * 64]u8 = undefined; // wasm page size
    var writer = std.io.Writer.fixed(&output);

    const len = parseDjot(input, &writer) catch |err| blk: {
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
