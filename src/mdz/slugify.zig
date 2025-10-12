//! Slugify is a cleanly and simple Zig slugifier. What makes this
//! slugifier different from others is the cleanliness of the resulting
//! slugs.
//!
//! Slugify is intended for url slugs but can be repurposed for
//! anything.
//!
//! See tests below for examples.
//!
//! This module is directly translated from my JavaScript
//! implementation at https://jsr.io/@bossley9/slugify.

const std = @import("std");

/// Converts x into a string slug identifier, then writes the result to
/// output and returns the length. The length of output must be greater
/// than or equal to the length of x or undefined behavior may occur.
pub fn slugify(x: []u8, output: []u8) usize {
    std.debug.assert(output.len >= x.len);
    var i: usize = 0;
    var is_prev_delimiter = false;

    for (x) |c| switch (c) {
        'A'...'Z' => {
            output[i] = std.ascii.toLower(c);
            i += 1;
            is_prev_delimiter = false;
        },
        '0'...'9', 'a'...'z' => {
            output[i] = c;
            i += 1;
            is_prev_delimiter = false;
        },
        else => {
            if (i > 0 and !is_prev_delimiter) {
                output[i] = '-';
                i += 1;
                is_prev_delimiter = true;
            }
        },
    };

    return if (output[i - 1] == '-') i - 1 else i;
}

fn expectSlugify(comptime input: []const u8, comptime output: []const u8) !void {
    var buf: [input.len]u8 = undefined;
    const len = slugify(@constCast(input), &buf);
    std.testing.expect(std.mem.eql(
        u8,
        output[0..output.len],
        buf[0..len],
    )) catch |err| {
        std.log.err("Expected:\n\n'{s}'\n\nBut instead received:\n\n'{s}'\n", .{ output[0..output.len], buf[0..len] });
        return err;
    };
}

test "base case" {
    const input = "Hello, world!";
    const output = "hello-world";
    try expectSlugify(input, output);
}

test "strips non-ascii characters" {
    const input = "你好, Hâllō good frєnd 😜";
    const output = "h-ll-good-fr-nd";
    try expectSlugify(input, output);
}

test "inserts a single dash between word boundaries" {
    const input = "what  is the meaning    of life?";
    const output = "what-is-the-meaning-of-life";
    try expectSlugify(input, output);
}

test "groups multiple word boundaries" {
    const input = "hello--------world";
    const output = "hello-world";
    try expectSlugify(input, output);
}

test "strips trailing whitespace" {
    const input = "   what is that whitespace?    ";
    const output = "what-is-that-whitespace";
    try expectSlugify(input, output);
}

test "strips trailing dashes" {
    const input = "----how are you-----";
    const output = "how-are-you";
    try expectSlugify(input, output);
}

test "converts underscores to dashes" {
    const input = "it_was_the_best_of_times";
    const output = "it-was-the-best-of-times";
    try expectSlugify(input, output);
}
