const std = @import("std");

pub const Document = struct {
    open_stack: std.ArrayList(Block),
    content: std.ArrayList(Block),
};

pub const Block = union(enum) {
    paragraph: Paragraph,
    block_quote: BlockQuote,
};

pub const Paragraph = struct {
    content: std.ArrayList(u8),
};

pub const BlockQuote = struct {
    content: std.ArrayList(Block),
};
