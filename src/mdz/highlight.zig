const std = @import("std");
const ast = @import("./ast.zig");
const parser = @import("./parser.zig");
const th = @import("./test_helpers.zig");

const Io = std.Io;

const SyntaxGroup = enum {
    addition,
    attr,
    comment,
    deletion,
    meta,
    plain,
    section,
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

/// Format and print keyword if it exists.
fn writeKeywordIfExists(w: *Io.Writer, line: []u8, i: *usize, kind: enum { keyword, builtin }, keyword: []const u8) Io.Writer.Error!usize {
    var len: usize = 0;
    const does_start_match = i.* == 0 or !std.ascii.isAlphanumeric(line[i.* - 1]);
    if (!does_start_match) return len;
    if (!lookAheadHas(line, i.*, keyword)) return len;
    const does_end_match = i.* + keyword.len == line.len or !std.ascii.isAlphanumeric(line[i.* + keyword.len]);
    if (!does_end_match) return len;

    i.* += keyword.len;
    len += try w.write(if (kind == .builtin) "<span class=\"lang-builtin\">" else "<span class=\"lang-keyword\">");
    len += try w.write(keyword);
    len += try w.write("</span>");

    return len;
}

fn changeSyntaxGroup(w: *Io.Writer, current_group: *SyntaxGroup, new_group: SyntaxGroup) Io.Writer.Error!usize {
    current_group.* = new_group;
    return switch (new_group) {
        .addition => try w.write("<span class=\"lang-addition\">"),
        .attr => try w.write("<span class=\"lang-attr\">"),
        .comment => try w.write("<span class=\"lang-comment\">"),
        .deletion => try w.write("<span class=\"lang-deletion\">"),
        .meta => try w.write("<span class=\"lang-meta\">"),
        .plain => try w.write("</span>"),
        .section => try w.write("<span class=\"lang-section\">"),
        .string_single, .string_double => try w.write("<span class=\"lang-string\">"),
    };
}

/// Rudimentary code highlighter that operates on individual lines of code
/// using basic forward and backward lookup
pub fn highlight_code_line(w: *Io.Writer, line: []u8, lang: ast.CodeLanguage) Io.Writer.Error!usize {
    var len: usize = 0;
    var i: usize = 0;
    var group: SyntaxGroup = .plain;
    var group_index: usize = 0;

    const has_colon = lang == .yaml and (std.mem.indexOfScalar(u8, line, ':') orelse 0) > 0;
    const has_bracket = lang == .css and (std.mem.indexOfScalar(u8, line, '{') orelse 0) > 0;

    while (i < line.len) : (i += 1) {
        switch (lang) {
            .css => {
                if (i == 0 and has_bracket) {
                    len += try changeSyntaxGroup(w, &group, .attr);
                    group_index = i;
                } else if (i != group_index and lookAheadHas(line, i, " {")) {
                    len += try changeSyntaxGroup(w, &group, .plain);
                }
                len += try parser.printEscapedHtml(line[i], w);
            },
            .diff, .patch => {
                if (group == .plain) {
                    if (lookAheadHas(line, i, "index") or
                        lookAheadHas(line, i, "diff") or
                        lookAheadHas(line, i, "---") or
                        lookAheadHas(line, i, "+++"))
                    {
                        len += try changeSyntaxGroup(w, &group, .comment);
                        group_index = i;
                    } else if (i == 0 and line[i] == '-') {
                        len += try changeSyntaxGroup(w, &group, .deletion);
                        group_index = i;
                    } else if (i == 0 and line[i] == '+') {
                        len += try changeSyntaxGroup(w, &group, .addition);
                        group_index = i;
                    } else if (lookAheadHas(line, i, "@@")) {
                        len += try changeSyntaxGroup(w, &group, .meta);
                        group_index = i;
                    }
                }

                len += try parser.printEscapedHtml(line[i], w);

                if (i != group_index) {
                    if (group == .meta and lookBehindHas(line, i, "@@")) {
                        len += try changeSyntaxGroup(w, &group, .plain);
                    }
                }
            },
            .ini => {
                if (i == 0) {
                    if (line[i] == '[') {
                        len += try changeSyntaxGroup(w, &group, .section);
                        group_index = i;
                    } else if (line[i] == '#') {
                        len += try changeSyntaxGroup(w, &group, .comment);
                        group_index = i;
                    } else {
                        len += try changeSyntaxGroup(w, &group, .attr);
                        group_index = i;
                    }
                } else if (group == .plain) {
                    if (line[i] == '"') {
                        len += try changeSyntaxGroup(w, &group, .string_double);
                        group_index = i;
                    } else if (line[i] == '#') {
                        len += try changeSyntaxGroup(w, &group, .comment);
                        group_index = i;
                    }
                }

                if (i != group_index) {
                    if (group == .attr and lookAheadHas(line, i, " =")) {
                        len += try changeSyntaxGroup(w, &group, .plain);
                    }
                }

                len += try parser.printEscapedHtml(line[i], w);

                if (i != group_index) {
                    if (group == .string_double and lookBehindHas(line, i, "\"") and !lookBehindHas(line, i, "\\\"")) {
                        len += try changeSyntaxGroup(w, &group, .plain);
                    }
                }
            },
            .sh => {
                if (i == 0 and lookAheadHas(line, i, "#!")) {
                    len += try changeSyntaxGroup(w, &group, .meta);
                    group_index = i;
                } else if (group == .plain) {
                    if (lookAheadHas(line, i, "#")) {
                        len += try changeSyntaxGroup(w, &group, .comment);
                        group_index = i;
                    } else if (line[i] == '\'') {
                        len += try changeSyntaxGroup(w, &group, .string_single);
                        group_index = i;
                    } else if (line[i] == '"') {
                        len += try changeSyntaxGroup(w, &group, .string_double);
                        group_index = i;
                    } else {
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "fi");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "if");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "then");

                        len += try writeKeywordIfExists(w, line, &i, .builtin, "cd");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "chgrp");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "chmod");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "chown");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "cp");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "echo");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "mkdir");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "mv");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "printf");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "rm");

                        if (i >= line.len) break;
                    }
                }

                len += try parser.printEscapedHtml(line[i], w);

                if (i != group_index) {
                    if (group == .string_single and lookBehindHas(line, i, "'") and !lookBehindHas(line, i, "\\'")) {
                        len += try changeSyntaxGroup(w, &group, .plain);
                    } else if (group == .string_double and lookBehindHas(line, i, "\"") and !lookBehindHas(line, i, "\\\"")) {
                        len += try changeSyntaxGroup(w, &group, .plain);
                    }
                }
            },
            .vim => {
                if (group == .plain) {
                    if (lookAheadHas(line, i, "\" ")) {
                        len += try changeSyntaxGroup(w, &group, .comment);
                    } else if (line[i] == '\'') {
                        len += try changeSyntaxGroup(w, &group, .string_single);
                        group_index = i;
                    } else if (line[i] == '"') {
                        len += try changeSyntaxGroup(w, &group, .string_double);
                        group_index = i;
                    } else {
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "let");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "set");

                        if (i >= line.len) break;
                    }
                }
                len += try parser.printEscapedHtml(line[i], w);
                if (i != group_index) {
                    if (group == .string_single and lookBehindHas(line, i, "'") and !lookBehindHas(line, i, "\\'")) {
                        len += try changeSyntaxGroup(w, &group, .plain);
                    } else if (group == .string_double and lookBehindHas(line, i, "\"") and !lookBehindHas(line, i, "\\\"")) {
                        len += try changeSyntaxGroup(w, &group, .plain);
                    }
                }
            },
            .yaml => {
                if (line[i] == '#') {
                    if (group != .plain) {
                        len += try changeSyntaxGroup(w, &group, .plain);
                    }
                    len += try changeSyntaxGroup(w, &group, .comment);
                    group_index = i;
                } else if (i == 0 and has_colon) {
                    len += try changeSyntaxGroup(w, &group, .attr);
                    group_index = i;
                } else if (group == .plain and std.ascii.isAlphanumeric(line[i])) {
                    len += try changeSyntaxGroup(w, &group, .string_single);
                    group_index = i;
                }

                len += try parser.printEscapedHtml(line[i], w);

                if (group_index != i) {
                    if (group == .attr and lookBehindHas(line, i, ":") and i + 1 < line.len) {
                        len += try changeSyntaxGroup(w, &group, .plain);
                        len += try changeSyntaxGroup(w, &group, .string_single);
                        group_index = i;
                    }
                }
            },
            else => len += try parser.printEscapedHtml(line[i], w),
        }
    }

    if (group != .plain) {
        len += try changeSyntaxGroup(w, &group, .plain);
    }

    return len + try w.write("\n");
}

test "css" {
    const input =
        \\.inlineSelector { display: none; }
        \\div > div > #complexSelector:has(.something) {
        \\  display: block;
        \\}
        \\div {
        \\  display: block;
        \\}
        \\
    ;
    const output =
        \\<span class="lang-attr">.inlineSelector</span> { display: none; }
        \\<span class="lang-attr">div &gt; div &gt; #complexSelector:has(.something)</span> {
        \\  display: block;
        \\}
        \\<span class="lang-attr">div</span> {
        \\  display: block;
        \\}
        \\
    ;
    try th.expectCodeHighlight(.css, input, output);
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

test "ini" {
    const input =
        \\# comment
        \\[section]
        \\key = "value" # another comment
        \\another-key = "another value"
        \\array = ["1", "2", "3"]
        \\
    ;
    const output =
        \\<span class="lang-comment"># comment</span>
        \\<span class="lang-section">[section]</span>
        \\<span class="lang-attr">key</span> = <span class="lang-string">"value"</span> <span class="lang-comment"># another comment</span>
        \\<span class="lang-attr">another-key</span> = <span class="lang-string">"another value"</span>
        \\<span class="lang-attr">array</span> = [<span class="lang-string">"1"</span>, <span class="lang-string">"2"</span>, <span class="lang-string">"3"</span>]
        \\
    ;
    try th.expectCodeHighlight(.ini, input, output);
}

test "sh" {
    const input =
        \\#!/bin/sh
        \\
        \\# comment
        \\echo "Hello 'john'!"
        \\echo 'another \' string' # trailing comment
        \\ifconfig
        \\
        \\if something; then
        \\  rm -rf /
        \\fi
        \\
    ;
    const output =
        \\<span class="lang-meta">#!/bin/sh</span>
        \\
        \\<span class="lang-comment"># comment</span>
        \\<span class="lang-builtin">echo</span> <span class="lang-string">"Hello 'john'!"</span>
        \\<span class="lang-builtin">echo</span> <span class="lang-string">'another \' string'</span> <span class="lang-comment"># trailing comment</span>
        \\ifconfig
        \\
        \\<span class="lang-keyword">if</span> something; <span class="lang-keyword">then</span>
        \\  <span class="lang-builtin">rm</span> -rf /
        \\<span class="lang-keyword">fi</span>
        \\
    ;
    try th.expectCodeHighlight(.sh, input, output);
}

test "vim" {
    const input =
        \\set viminfo="" " comment with string in line
        \\
        \\let g:args = [
        \\  'hello',
        \\  'world',
        \\  '123',
        \\]
        \\
    ;
    const output =
        \\<span class="lang-keyword">set</span> viminfo=<span class="lang-string">""</span> <span class="lang-comment">" comment with string in line</span>
        \\
        \\<span class="lang-keyword">let</span> g:args = [
        \\  <span class="lang-string">'hello'</span>,
        \\  <span class="lang-string">'world'</span>,
        \\  <span class="lang-string">'123'</span>,
        \\]
        \\
    ;
    try th.expectCodeHighlight(.vim, input, output);
}

test "yaml" {
    const input =
        \\key: value # : is separator
        \\list:
        \\  - val1
        \\  - val2
        \\  - val3 # inline comment
        \\# comment
        \\nested:
        \\  - values: |
        \\      hello
        \\      world
        \\  # comment
        \\
    ;
    const output =
        \\<span class="lang-attr">key:</span><span class="lang-string"> value </span><span class="lang-comment"># : is separator</span>
        \\<span class="lang-attr">list:</span>
        \\  - <span class="lang-string">val1</span>
        \\  - <span class="lang-string">val2</span>
        \\  - <span class="lang-string">val3 </span><span class="lang-comment"># inline comment</span>
        \\<span class="lang-comment"># comment</span>
        \\<span class="lang-attr">nested:</span>
        \\<span class="lang-attr">  - values:</span><span class="lang-string"> |</span>
        \\      <span class="lang-string">hello</span>
        \\      <span class="lang-string">world</span>
        \\  <span class="lang-comment"># comment</span>
        \\
    ;
    try th.expectCodeHighlight(.yaml, input, output);
}
