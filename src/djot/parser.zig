const std = @import("std");
const ast = @import("./ast.zig");
const th = @import("./test_helpers.zig");

const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;
const ParserError = Allocator.Error;

fn closeOpenBlocks(allocator: Allocator, doc: *ast.Document) ParserError!void {
    var pendingBlock = doc.openStack.pop();
    while (doc.openStack.items.len > 0) {
        var parent = doc.openStack.pop().?;

        switch (parent) {
            .block_quote => |*_parent| {
                try _parent.content.append(allocator, pendingBlock.?);
                pendingBlock = parent;
            },
            .paragraph => {},
        }
    }
    if (pendingBlock) |block| {
        try doc.content.append(allocator, block);
    }
}

pub fn parseDocument(allocator: Allocator, input: []u8, doc: *ast.Document) ParserError!void {
    var line_start: usize = 0;
    var pos: usize = 0;
    while (pos <= input.len) : (pos += 1) {
        if (pos == input.len or input[pos] == '\n') {
            const line_end = if (pos - 1 > 0 and input[pos - 1] == '\r') blk: {
                @branchHint(.cold); // stop using Windows please!
                break :blk pos - 1;
            } else pos;
            const line = input[line_start..line_end];

            if (line.len == 0) {
                // blank line
                try closeOpenBlocks(allocator, doc);
            } else if (line[0] == '>' and (line.len == 1 or line[1] == ' ')) {
                // blockquote
                const content = try std.array_list.Aligned(ast.Block, null).initCapacity(allocator, 0);
                const blockQuote = ast.Block{
                    .block_quote = ast.BlockQuote{
                        .content = content,
                    },
                };
                try doc.openStack.append(allocator, blockQuote);

                if (line.len > 2) {
                    const paragraph = ast.Block{
                        .paragraph = ast.Paragraph{
                            .inlineStart = line_start + 2,
                            .inlineEnd = line_end,
                        },
                    };
                    try doc.openStack.append(allocator, paragraph);
                }
            } else {
                // paragraph
                const paragraph = ast.Block{
                    .paragraph = ast.Paragraph{
                        .inlineStart = line_start,
                        .inlineEnd = line_end,
                    },
                };
                try doc.openStack.append(allocator, paragraph);
            }

            line_start = pos + 1;
        }
    }

    try closeOpenBlocks(allocator, doc);
}

test "paragraph single" {
    try th.expectParseDjot("Hello, world!", "<p>Hello, world!</p>");
}

test "paragraph multiple" {
    try th.expectParseDjot(
        \\Hello, world!
        \\
        \\What is your name?
    ,
        \\<p>Hello, world!</p>
        \\<p>What is your name?</p>
    );
}

test "blockquote empty" {
    try th.expectParseDjot(
        \\>
    ,
        \\<blockquote>
        \\</blockquote>
    );
}

test "blockquote empty with space" {
    try th.expectParseDjot(
        \\> 
    ,
        \\<blockquote>
        \\</blockquote>
    );
}

test "blockquote single line" {
    try th.expectParseDjot(
        \\> This is a block quote.
    ,
        \\<blockquote>
        \\<p>This is a block quote.</p>
        \\</blockquote>
    );
}
