// # Markdown-Z (MDZ)
const th = @import("./test_helpers.zig");

test "0.0.1" {
    const input =
        \\Hello, world!
    ;
    const output =
        \\Hello, world!
    ;
    try th.expectParseMDZ(input, output);
}
