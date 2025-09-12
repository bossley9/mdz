const std = @import("std");

pub const BlockTag = enum {
    document,
    thematic_break,
    heading,
    paragraph,
    block_quote,
};

pub const Block = struct {
    tag: BlockTag,
    open: bool,
    level: u3,
    inlines: ?std.ArrayList(u8),
    content: ?std.ArrayList(Block),

    pub fn init(
        allocator: std.mem.Allocator,
        tag: BlockTag,
    ) std.mem.Allocator.Error!Block {
        const has_inlines = switch (tag) {
            .thematic_break, .heading, .paragraph => true,
            else => false,
        };
        return .{
            .tag = tag,
            .open = true,
            .level = 0,
            .inlines = if (has_inlines)
                try std.ArrayList(u8).initCapacity(allocator, 0)
            else
                null,
            .content = if (has_inlines)
                null
            else
                try std.ArrayList(Block).initCapacity(allocator, 0),
        };
    }
};
