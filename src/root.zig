const std = @import("std");
const p = @import("./djot/parsers.zig");
const th = @import("./djot/test_helpers.zig");

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
        @branchHint(.cold); // stop using Windows please!
        return result[0 .. result.len - 2];
    }

    return result[0 .. result.len - 1];
}

const ParseDjotError = Reader.DelimiterError || Writer.Error;

/// Given a Djot input reader and an output writer, parse and write the
/// corresponding HTML string to the writer, then return the number of
/// bytes written.
pub fn parseDjot(r: *Reader, w: *Writer) ParseDjotError!usize {
    while (takeNewlineExclusive(r)) |line| {
        try p.parseLine(line, w);
    } else |err| switch (err) {
        Reader.DelimiterError.EndOfStream => {}, // end of input
        else => return err,
    }

    try w.flush();
    return w.end;
}

test "basic test" {
    try th.expectParseDjot("Hello", "Line: Hello\n");
}

const wasm_page_size = 1024 * 64;

/// Given a Djot input string address, parse and write the corresponding
/// HTML output string to memory, then return the length. An error is
/// returned as the string "error.message", where `message` represents
/// the error message.
export fn parseDjotWasm(input_addr: [*]u8, input_len: usize) usize {
    if (input_len == 0) {
        @branchHint(.cold);
        return 0;
    }

    var reader = Reader.fixed(input_addr[0..input_len]);
    var output: [wasm_page_size]u8 = undefined;
    var writer = Writer.fixed(&output);

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
