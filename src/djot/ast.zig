const std = @import("std");

pub const Paragraph = struct {
    inlineStart: usize,
    inlineEnd: usize,
};

pub const BlockQuote = struct {
    content: std.ArrayList(Block),
};

pub const Block = union(enum) {
    paragraph: Paragraph,
    block_quote: BlockQuote,
};

pub const Document = struct {
    openStack: std.ArrayList(Block),
    content: std.ArrayList(Block),
};
