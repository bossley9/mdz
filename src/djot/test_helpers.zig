const std = @import("std");
const mod = @import("../root.zig");

pub fn expectParseDjot(input: []const u8, comptime expected: []const u8) !void {
    var reader = std.io.Reader.fixed(input);
    var expected_buf: [expected.len * 2]u8 = undefined;
    var writer = std.io.Writer.fixed(&expected_buf);

    const len = try mod.parseDjot(&reader, &writer);
    std.testing.expect(std.mem.eql(u8, expected_buf[0..len], expected)) catch |err| {
        std.log.err("Expected: '{s}', received '{s}'\n", .{ expected, expected_buf[0..len] });
        return err;
    };
}
