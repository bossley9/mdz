const std = @import("std");
const ast = @import("./ast.zig");

const Writer = std.io.Writer;

fn printBlock(block: *ast.Block, input: []u8, w: *Writer, newline: bool) Writer.Error!void {
    switch (block.*) {
        .paragraph => |*_block| {
            try w.print("{s}<p>", .{if (newline) "\n" else ""});
            const slice = _block.content.items;

            // valgrind freaks out with strings > 63 bytes
            var i: usize = 0;
            while (i + 63 < slice.len) : (i += 63) {
                try w.print("{s}", .{slice[i .. i + 63]});
            }
            try w.print("{s}", .{slice[i..slice.len]});

            try w.print("</p>", .{});
        },
        .block_quote => |_block| {
            try w.print("{s}<blockquote>", .{if (newline) "\n" else ""});
            for (_block.content.items) |*item| {
                try printBlock(item, input, w, true);
            }
            try w.print("\n</blockquote>", .{});
        },
    }
}

pub fn printDocument(doc: *ast.Document, input: []u8, w: *Writer) Writer.Error!void {
    for (doc.content.items, 0..) |*block, i| {
        try printBlock(block, input, w, i != 0);
    }
}
