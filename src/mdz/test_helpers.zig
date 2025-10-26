const std = @import("std");
const mod = @import("../mdz/parser.zig");

pub fn expectParseMDZ(input: []const u8, comptime expected: []const u8) !void {
    var reader = std.io.Reader.fixed(input);
    var expected_buf: [expected.len * 6]u8 = undefined;
    var writer = std.io.Writer.fixed(&expected_buf);

    const len = try mod.parseMDZ(&reader, &writer);
    std.testing.expect(std.mem.eql(u8, expected_buf[0..len], expected)) catch |err| {
        std.log.err("Expected:\n\n{s}\n\nBut instead received:\n\n{s}\n", .{ expected, expected_buf[0..len] });
        return err;
    };
}
