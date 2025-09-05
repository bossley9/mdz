const std = @import("std");

const Writer = std.io.Writer;

pub fn parseLine(line: []u8, w: *Writer) Writer.Error!void {
    try w.print("Line: {s}\n", .{line});
}
