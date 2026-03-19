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
    std.testing.expect(std.mem.eql(u8, expected_buf[0..len], expected)) catch |e| {
        std.log.err("Expected:\n\n{s}\n\nBut instead received:\n\n{s}\n", .{ expected, expected_buf[0..len] });
        return e;
    };
    std.testing.expect(len == expected.len) catch |e| {
        std.log.err("Expected length:\n\n{d}\n\nBut instead received:\n\n{d}\n", .{ expected.len, len });
        return e;
    };
}

pub fn expectCodeHighlight(
    lang: ast.CodeLanguage,
    comptime input: []const u8,
    comptime expected: []const u8,
) !void {
    var reader = Io.Reader.fixed(input);
    var expected_buf: [expected.len * 5]u8 = undefined;
    var writer = Io.Writer.fixed(&expected_buf);
    var len: usize = 0;

    while (reader.takeDelimiterInclusive('\n')) |line| {
        len += try highlight.highlight_code_line(&writer, line[0 .. line.len - 1], lang);
    } else |e| switch (e) {
        Io.Reader.Error.EndOfStream => {},
        else => return e,
    }

    std.testing.expect(std.mem.eql(u8, expected_buf[0..len], expected)) catch |e| {
        std.log.err("Expected:\n\n{s}\n\nBut instead received:\n\n{s}\n", .{ expected, expected_buf[0..len] });
        return e;
    };
    std.testing.expect(len == expected.len) catch |e| {
        std.log.err("Expected length:\n\n{d}\n\nBut instead received:\n\n{d}\n", .{ expected.len, len });
        return e;
    };
}
