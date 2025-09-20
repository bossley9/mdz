const std = @import("std");

pub const BlockTag = enum {
    document,
    // leaf blocks
    paragraph,
    thematic_break,
    heading,
    code_block,
    html_block,
    // container blocks
    block_quote,
    list,
    list_item,
    // inlines
    text,
};

pub const ListType = enum(u1) {
    unordered,
    ordered,
};

pub const Block = struct {
    tag: BlockTag,
    open: bool,
    level: u3, // heading
    lang: [20:0]u8, // code block
    is_list_paragraph: bool, // list_item paragraph
    list_type: ListType,
    inlines: ?std.ArrayList(u8),
    content: ?std.ArrayList(Block),

    pub fn init(
        allocator: std.mem.Allocator,
        tag: BlockTag,
    ) std.mem.Allocator.Error!Block {
        const has_children = switch (tag) {
            .code_block, .text => false,
            else => true,
        };
        const has_inlines = switch (tag) {
            .paragraph,
            .heading,
            // literals
            .code_block,
            .html_block,
            .text,
            => true,
            else => false,
        };
        return .{
            .tag = tag,
            .open = true,
            .level = 0,
            .lang = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            .is_list_paragraph = false,
            .list_type = ListType.unordered,
            // only for storing temporary inlines
            // except in the case of literals
            .inlines = if (has_inlines)
                try std.ArrayList(u8).initCapacity(allocator, 0)
            else
                null,
            .content = if (has_children)
                try std.ArrayList(Block).initCapacity(allocator, 0)
            else
                null,
        };
    }
};
