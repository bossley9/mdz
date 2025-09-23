const std = @import("std");

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

fn processLine(line: []u8, w: *Writer) Writer.Error!void {
    try w.print("{s}", .{line});
}

pub const ProcessDocumentError = error{ ReadFailed, StreamTooLong, WriteFailed };

/// Read an MDZ document from a input reader and incrementally write
/// the output to writer.
pub fn processDocument(r: *Reader, w: *Writer) ProcessDocumentError!void {
    while (takeNewlineExclusive(r)) |line| {
        try processLine(line, w);
    } else |e| switch (e) {
        Reader.DelimiterError.EndOfStream => {}, // end of input
        Reader.DelimiterError.ReadFailed,
        Reader.DelimiterError.StreamTooLong,
        => |err| return err,
    }
}
