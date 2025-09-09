const std = @import("std");

pub const BlockTag = enum {
    document,
    paragraph,
    block_quote,
};

pub const Block = struct {
    tag: BlockTag,
    open: bool,
    inlines: ?std.ArrayList(u8),
    content: ?std.ArrayList(Block),

    pub fn init(
        allocator: std.mem.Allocator,
        tag: BlockTag,
    ) std.mem.Allocator.Error!Block {
        const has_inlines = tag == .paragraph;
        return .{
            .tag = tag,
            .open = true,
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
