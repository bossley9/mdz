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
            for (block.content.?.items) |*child| {
                try printDocument(child, w);
            }
            try w.print("</p>\n", .{});
        },
        .thematic_break => try w.print("<hr />\n", .{}),
        .heading => {
            try w.print("<h{d}>", .{block.level});
            for (block.content.?.items) |*child| {
                try printDocument(child, w);
            }
            try w.print("</h{d}>\n", .{block.level});
        },
        .code_block => {
            var langLen: usize = 0;
            while (block.lang[langLen] != 0) : (langLen += 1) {}
            if (langLen > 0) {
                try w.print("<pre><code class=\"language-{s}\">", .{
                    block.lang[0..langLen],
                });
            } else {
                try w.print("<pre><code>", .{});
            }
            for (block.inlines.?.items) |c| {
                try w.print("{c}", .{c});
            }
            try w.print("</code></pre>\n", .{});
        },
        .block_quote => {
            try w.print("<blockquote>\n", .{});
            for (block.content.?.items) |*child| {
                try printDocument(child, w);
            }
            try w.print("</blockquote>\n", .{});
        },
        .html_block, .text => {
            // Valgrind panics when printing char arrays
            for (block.inlines.?.items) |c| {
                try w.print("{c}", .{c});
            }
        },
    }
}
