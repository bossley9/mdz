const std = @import("std");

pub const BlockTag = enum {
    document,
    // leaf blocks
    paragraph,
    thematic_break,
    heading,
    code_block,
    // container blocks
    block_quote,
};

pub const Block = struct {
    tag: BlockTag,
    open: bool,
    level: u3,
    pending_inlines: ?std.ArrayList(u8),
    content: ?std.ArrayList(Block),

    pub fn init(
        allocator: std.mem.Allocator,
        tag: BlockTag,
    ) std.mem.Allocator.Error!Block {
        // TODO implement inlines
        const is_inline = false;
        const has_inlines = switch (tag) {
            .paragraph, .heading, .code_block => true,
            else => false,
        };
        return .{
            .tag = tag,
            .open = true,
            .level = 0,
            .pending_inlines = if (has_inlines)
                try std.ArrayList(u8).initCapacity(allocator, 0)
            else
                null,
            .content = if (is_inline)
                null
            else
                try std.ArrayList(Block).initCapacity(allocator, 0),
        };
    }
};
