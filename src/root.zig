const std = @import("std");

pub fn parseDjot() []const u8 {
    return "Hello";
}

test "basic test" {
    try std.testing.expect(std.mem.eql(u8, parseDjot(), "Hello"));
}
