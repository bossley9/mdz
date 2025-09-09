const std = @import("std");
const ast = @import("./ast.zig");

const Writer = std.io.Writer;

pub fn printDocument(block: *ast.Block, w: *Writer) Writer.Error!void {
    switch (block.tag) {
        .document => {
            for (block.content.?.items) |*child| {
                try printDocument(child, w);
            }
        },
        .paragraph => {
            try w.print("<p>", .{});
            // Valgrind panics when printing char arrays
            for (block.inlines.?.items) |c| {
                try w.print("{c}", .{c});
            }
            try w.print("</p>\n", .{});
        },
        .block_quote => {
            try w.print("<blockquote>\n", .{});
            for (block.content.?.items) |*child| {
                try printDocument(child, w);
            }
            try w.print("</blockquote>\n", .{});
        },
    }
}
