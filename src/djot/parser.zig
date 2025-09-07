const std = @import("std");
const ast = @import("./ast.zig");
const th = @import("./test_helpers.zig");

const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;
const ParserError = Allocator.Error;

fn pushOpenParagraph(allocator: Allocator, doc: *ast.Document, line: []u8) ParserError!void {
    var content = try std.ArrayList(u8).initCapacity(allocator, 0);
    for (line) |c| {
        try content.append(allocator, c);
    }
    const paragraph = ast.Block{
        .paragraph = ast.Paragraph{
            .content = content,
        },
    };
    try doc.open_stack.append(allocator, paragraph);
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

test "paragraph lazy continuation" {
    try th.expectParseDjot(
        \\aaa
        \\bbb
        \\
        \\ccc
        \\ddd
    ,
        \\<p>aaa
        \\bbb</p>
        \\<p>ccc
        \\ddd</p>
    );
}

fn closeOpenBlocks(allocator: Allocator, doc: *ast.Document) ParserError!void {
    var pending_block = doc.open_stack.pop();
    while (doc.open_stack.items.len > 0) {
        var parent = doc.open_stack.pop().?;

        switch (parent) {
            .block_quote => |*_parent| {
                try _parent.content.append(allocator, pending_block.?);
                pending_block = parent;
            },
            .paragraph => {},
        }
    }
    if (pending_block) |block| {
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

            if (line.len == 0) { // blank line
                try closeOpenBlocks(allocator, doc);
            } else if (line[0] == '>' and (line.len == 1 or line[1] == ' ')) { // blockquote
                const content = try std.ArrayList(ast.Block).initCapacity(allocator, 0);
                const blockQuote = ast.Block{
                    .block_quote = ast.BlockQuote{
                        .content = content,
                    },
                };
                try doc.open_stack.append(allocator, blockQuote);

                if (line.len > 2) {
                    try pushOpenParagraph(allocator, doc, line[2..]);
                }
            } else { // paragraph
                if (doc.open_stack.items.len > 0) {
                    switch (doc.open_stack.items[doc.open_stack.items.len - 1]) {
                        .paragraph => |*para| {
                            try para.content.append(allocator, '\n');
                            for (line) |c| {
                                try para.content.append(allocator, c);
                            }
                        },
                        else => {
                            try pushOpenParagraph(allocator, doc, line);
                        },
                    }
                } else {
                    try pushOpenParagraph(allocator, doc, line);
                }
            }

            line_start = pos + 1;
        }
    }

    try closeOpenBlocks(allocator, doc);
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
