const ast = @import("./ast.zig");
const std = @import("std");
const mod = @import("../mdz/parser.zig");
const highlight = @import("./highlight.zig");

const Io = std.Io;

pub fn expectParseMDZ(input: []const u8, comptime expected: []const u8) !void {
    var reader = Io.Reader.fixed(input);
    var expected_buf: [expected.len * 6]u8 = undefined;
    var writer = Io.Writer.fixed(&expected_buf);

    const len = try mod.parseMDZ(&reader, &writer);
    try std.testing.expectEqualStrings(expected_buf[0..len], expected);
}

pub fn expectCodeHighlight(
    lang: ast.CodeLanguage,
    comptime input: []const u8,
    comptime expected: []const u8,
) !void {
    var reader = Io.Reader.fixed(input);
    var expected_buf: [expected.len * 7]u8 = undefined;
    var writer = Io.Writer.fixed(&expected_buf);
    var len: usize = 0;

    while (reader.takeDelimiterInclusive('\n')) |line| {
        len += try highlight.highlight_code_line(&writer, line[0 .. line.len - 1], lang);
    } else |e| switch (e) {
        Io.Reader.Error.EndOfStream => {},
        else => return e,
    }

    try std.testing.expectEqualStrings(expected_buf[0..len], expected);
}
