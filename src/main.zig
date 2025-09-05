const std = @import("std");
const mod = @import("./root.zig");

pub fn main() !void {
    std.log.debug("{s}", .{mod.parseDjot()});
}

test {
    std.testing.refAllDecls(@This());
}
