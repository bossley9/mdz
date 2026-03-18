const std = @import("std");
const ast = @import("./ast.zig");
const parser = @import("./parser.zig");
const th = @import("./test_helpers.zig");

const Io = std.Io;

const SyntaxGroup = enum {
    addition,
    comment,
    deletion,
    meta,
    plain,
    string_single,
    string_double,
};

/// Return true if the characters ahead match the pattern.
fn lookAheadHas(line: []u8, i: usize, pattern: []const u8) bool {
    if (i + pattern.len > line.len) return false;
    return std.mem.eql(u8, line[i .. i + pattern.len], pattern);
}

/// Return true if the characters behind match the pattern.
fn lookBehindHas(line: []u8, i: usize, pattern: []const u8) bool {
    if (pattern.len > i) return false;
    return std.mem.eql(u8, line[i - pattern.len + 1 .. i + 1], pattern);
}

/// Rudimentary code highlighter that operates on individual lines of code
/// using basic forward and backward lookup
pub fn highlight_code_line(w: *Io.Writer, line: []u8, lang: ast.CodeLanguage) Io.Writer.Error!usize {
    var len: usize = 0;
    var i: usize = 0;
    var group: SyntaxGroup = .plain;

    while (i < line.len) : (i += 1) {
        switch (lang) {
            .diff, .patch => {
                if (group == .plain) {
                    if (lookAheadHas(line, i, "index") or
                        lookAheadHas(line, i, "diff") or
                        lookAheadHas(line, i, "---") or
                        lookAheadHas(line, i, "+++"))
                    {
                        group = .comment;
                        len += try w.write("<span class=\"lang-comment\">");
                    } else if (i == 0 and line[i] == '-') {
                        group = .deletion;
                        len += try w.write("<span class=\"lang-deletion\">");
                    } else if (i == 0 and line[i] == '+') {
                        group = .addition;
                        len += try w.write("<span class=\"lang-addition\">");
                    } else if (lookAheadHas(line, i, "@@")) {
                        group = .meta;
                        len += try w.write("<span class=\"lang-meta\">");
                    }
                }

                len += try parser.printEscapedHtml(line[i], w);

                if (group == .meta and lookBehindHas(line, i, "@@")) {
                    group = .plain;
                    len += try w.write("</span>");
                }
            },
            else => {
                len += try parser.printEscapedHtml(line[i], w);
            },
        }
    }

    if (group != .plain) {
        len += try w.write("</span>");
    }

    return len + try w.write("\n");
}

test "diff, patch" {
    const input =
        \\From: John Doe <test@example.com>
        \\Date: Fri, 2 Jan 2026 00:00:00 -0100
        \\Subject: [PATCH 1/1] something
        \\
        \\---
        \\ README.txt | 2 +-
        \\ 1 file changed, 1 insertion(+), 1 deletion(-)
        \\
        \\diff --git a/README.txt b/README.txt
        \\index 1234567..abcdef0 100644
        \\--- a/README.txt
        \\+++ b/README.txt
        \\@@ -1 +1 @@ test post func
        \\-test 123
        \\+123 test
        \\
    ;
    const output =
        \\From: John Doe &lt;test@example.com&gt;
        \\Date: Fri, 2 Jan 2026 00:00:00 -0100
        \\Subject: [PATCH 1/1] something
        \\
        \\<span class="lang-comment">---</span>
        \\ README.txt | 2 +-
        \\ 1 file changed, 1 insertion(+), 1 deletion(-)
        \\
        \\<span class="lang-comment">diff --git a/README.txt b/README.txt</span>
        \\<span class="lang-comment">index 1234567..abcdef0 100644</span>
        \\<span class="lang-comment">--- a/README.txt</span>
        \\<span class="lang-comment">+++ b/README.txt</span>
        \\<span class="lang-meta">@@ -1 +1 @@</span> test post func
        \\<span class="lang-deletion">-test 123</span>
        \\<span class="lang-addition">+123 test</span>
        \\
    ;
    try th.expectCodeHighlight(.diff, input, output);
    try th.expectCodeHighlight(.patch, input, output);
}
