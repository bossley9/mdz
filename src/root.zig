const std = @import("std");
const ast = @import("./rmd/ast.zig");
const parser = @import("./rmd/parser.zig");
const printer = @import("./rmd/printer.zig");
const mdz = @import("./mdz/parser.zig");

const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

const ParseRMDError = Reader.DelimiterError || Allocator.Error || Writer.Error;

fn freeBlock(block: *ast.Block, allocator: Allocator) void {
    if (block.inlines) |*inlines| {
        inlines.deinit(allocator);
    }
    if (block.content) |*content| {
        for (content.items) |*child| {
            freeBlock(child, allocator);
        }
        content.deinit(allocator);
    }
}

/// Given a RMD input reader and an output writer, parse and write the
/// corresponding HTML string to the writer, then return the number of
/// bytes written.
pub fn parseRMD(r: *Reader, w: *Writer) ParseRMDError!usize {
    const allocator = std.heap.page_allocator;
    var document = try ast.Block.init(allocator, .document);
    defer freeBlock(&document, allocator);

    try parser.parseDocument(allocator, r, &document);
    try printer.printDocument(&document, w);

    if (w.end > 0) {
        w.undo(1); // remove final newline from printed output
    }
    try w.flush();
    return w.end;
}

/// Given an MDZ input reader and an output writer, parse and write the
/// corresponding HTML string to the writer, then return the number of
/// bytes written.
pub fn parseMDZ(r: *Reader, w: *Writer) mdz.ProcessDocumentError!usize {
    try mdz.processDocument(r, w);

    if (w.end > 0) {
        w.undo(1); // remove final newline
    }
    try w.flush();
    return w.end;
}

/// Given a RMD input string address, parse and write the corresponding
/// HTML output string to memory, then return the length. An error is
/// returned as the string "error.message", where `message` represents
/// the error message.
export fn parseRMDWasm(input_addr: [*]u8, input_len: usize) usize {
    if (input_len == 0) {
        @branchHint(.cold);
        return 0;
    }

    const input = input_addr[0..input_len];
    var reader = Reader.fixed(input);

    var output: [std.wasm.page_size]u8 = undefined;
    var writer = Writer.fixed(&output);

    const len = parseRMD(&reader, &writer) catch |err| blk: {
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
