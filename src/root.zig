const std = @import("std");
const mdz = @import("./mdz/parser.zig");

const Reader = std.io.Reader;
const Writer = std.io.Writer;

/// Given an MDZ input string address, parse and write the corresponding
/// HTML output string to memory, then return the length. An error is
/// returned as the string "error.message", where `message` represents
/// the error message.
export fn parseMDZWasm(input_addr: [*]u8, input_len: usize) usize {
    if (input_len == 0) {
        @branchHint(.cold);
        return 0;
    }

    const input = input_addr[0..input_len];
    var reader = Reader.fixed(input);

    var output: [std.wasm.page_size]u8 = undefined;
    var writer = Writer.fixed(&output);

    const len = mdz.parseMDZ(&reader, &writer) catch |err| blk: {
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
