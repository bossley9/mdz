const std = @import("std");
const ast = @import("./ast.zig");
const parser = @import("./parser.zig");
const th = @import("./test_helpers.zig");

const Io = std.Io;

const SyntaxGroup = enum {
    addition,
    attr,
    boolean,
    comment,
    deletion,
    meta,
    number,
    plain,
    section,
    string_single,
    string_double,
    type,
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
fn writeKeywordIfExists(
    w: *Io.Writer,
    line: []u8,
    i: *usize,
    kind: enum { boolean, builtin, keyword, type },
    keyword: []const u8,
) Io.Writer.Error!usize {
    var len: usize = 0;
    const does_start_match = i.* == 0 or !std.ascii.isAlphanumeric(line[i.* - 1]);
    if (!does_start_match) return len;
    if (!lookAheadHas(line, i.*, keyword)) return len;
    const does_end_match = i.* + keyword.len == line.len or !std.ascii.isAlphanumeric(line[i.* + keyword.len]);
    if (!does_end_match) return len;

    i.* += keyword.len;
    len += try w.write(switch (kind) {
        .boolean => "<span class=\"lang-boolean\">",
        .builtin => "<span class=\"lang-builtin\">",
        .keyword => "<span class=\"lang-keyword\">",
        .type => "<span class=\"lang-type\">",
    });
    len += try w.write(keyword);
    len += try w.write("</span>");

    return len;
}

fn changeSyntaxGroup(w: *Io.Writer, current_group: *SyntaxGroup, new_group: SyntaxGroup) Io.Writer.Error!usize {
    current_group.* = new_group;
    return switch (new_group) {
        .addition => try w.write("<span class=\"lang-addition\">"),
        .attr => try w.write("<span class=\"lang-attr\">"),
        .boolean => try w.write("<span class=\"lang-boolean\">"),
        .comment => try w.write("<span class=\"lang-comment\">"),
        .deletion => try w.write("<span class=\"lang-deletion\">"),
        .meta => try w.write("<span class=\"lang-meta\">"),
        .number => try w.write("<span class=\"lang-number\">"),
        .plain => try w.write("</span>"),
        .section => try w.write("<span class=\"lang-section\">"),
        .string_single, .string_double => try w.write("<span class=\"lang-string\">"),
        .type => try w.write("<span class=\"lang-type\">"),
    };
}

/// Rudimentary code highlighter that operates on individual lines of code
/// using basic forward and backward lookup
pub fn highlight_code_line(w: *Io.Writer, line: []u8, lang: ast.CodeLanguage) Io.Writer.Error!usize {
    var len: usize = 0;
    var i: usize = 0;
    var group: SyntaxGroup = .plain;
    var group_index: usize = 0;

    const has_colon = (std.mem.indexOfScalar(u8, line, ':') orelse 0) > 0;
    const has_bracket = lang == .css and (std.mem.indexOfScalar(u8, line, '{') orelse 0) > 0;
    var num_spaces: usize = 0;

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
            .json => {
                if (i == 0 and has_colon) {
                    len += try changeSyntaxGroup(w, &group, .attr);
                    group_index = i;
                }

                if ((group == .attr and line[i] == ':')) {
                    len += try changeSyntaxGroup(w, &group, .plain);
                }

                if (group == .number and !std.ascii.isDigit(line[i]) and line[i] != '.') {
                    len += try changeSyntaxGroup(w, &group, .plain);
                }

                if (group == .plain) {
                    if (line[i] == '"') {
                        len += try changeSyntaxGroup(w, &group, .string_double);
                        group_index = i;
                    } else if (std.ascii.isDigit(line[i])) {
                        len += try changeSyntaxGroup(w, &group, .number);
                        group_index = i;
                    }
                }
                len += try parser.printEscapedHtml(line[i], w);
                if (group_index != i) {
                    if (group == .string_double and lookBehindHas(line, i, "\"") and !lookBehindHas(line, i, "\\\"")) {
                        len += try changeSyntaxGroup(w, &group, .plain);
                    }
                }
            },
            .sh, .crontab => {
                if (i == 0 and lookAheadHas(line, i, "#!")) {
                    len += try changeSyntaxGroup(w, &group, .meta);
                    group_index = i;
                } else if (group == .plain) {
                    if (lookAheadHas(line, i, "#")) {
                        len += try changeSyntaxGroup(w, &group, .comment);
                        group_index = i;
                    } else if (lang == .crontab and i == 0) {
                        len += try changeSyntaxGroup(w, &group, .section);
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

                if (line[i] == ' ' and group == .section) {
                    num_spaces += 1;
                    if (num_spaces > 4) {
                        len += try changeSyntaxGroup(w, &group, .plain);
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
            .zig => {
                if (group == .plain) {
                    if (lookAheadHas(line, i, "//")) {
                        len += try changeSyntaxGroup(w, &group, .comment);
                        group_index = i;
                    } else if (line[i] == '\'') {
                        len += try changeSyntaxGroup(w, &group, .string_single);
                        group_index = i;
                    } else if (line[i] == '"') {
                        len += try changeSyntaxGroup(w, &group, .string_double);
                        group_index = i;
                    } else {
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "addrspace");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "align");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "allowzero");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "and");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "anyframe");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "anytype");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "asm");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "break");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "callconv");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "catch");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "comptime");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "const");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "continue");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "defer");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "else");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "enum");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "errdefer");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "error");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "export");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "extern");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "fn");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "for");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "if");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "inline");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "noalias");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "nosuspend");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "noinline");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "opaque");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "or");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "orelse");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "packed");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "pub");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "resume");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "return");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "linksection");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "struct");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "suspend");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "switch");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "test");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "threadlocal");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "try");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "union");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "unreachable");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "var");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "volatile");
                        len += try writeKeywordIfExists(w, line, &i, .keyword, "while");

                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@addrSpaceCast");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@addWithOverflow");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@alignCast");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@alignOf");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@as");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@atomicLoad");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@atomicRmw");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@atomicStore");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@bitCast");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@bitOffsetOf");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@bitSizeOf");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@branchHint");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@breakpoint");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@mulAdd");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@byteSwap");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@bitReverse");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@offsetOf");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@call");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@cDefine");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@cImport");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@cInclude");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@clz");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@cmpxchgStrong");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@cmpxchgWeak");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@compileError");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@compileLog");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@constCast");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@ctz");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@cUndef");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@cVaArg");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@cVaCopy");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@cVaEnd");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@cVaStart");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@divExact");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@divFloor");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@divTrunc");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@embedFile");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@enumFromInt");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@errorFromInt");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@errorName");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@errorReturnTrace");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@errorCast");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@export");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@extern");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@field");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@fieldParentPtr");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@FieldType");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@floatCast");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@floatFromInt");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@frameAddress");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@hasDecl");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@hasField");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@import");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@inComptime");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@intCast");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@intFromBool");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@intFromEnum");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@intFromError");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@intFromFloat");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@intFromPtr");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@max");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@memcpy");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@memset");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@memmove");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@min");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@wasmMemorySize");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@wasmMemoryGrow");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@mod");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@mulWithOverflow");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@panic");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@popCount");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@prefetch");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@ptrCast");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@ptrFromInt");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@rem");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@returnAddress");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@select");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@setEvalBranchQuota");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@setFloatMode");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@setRuntimeSafety");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@shlExact");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@shlWithOverflow");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@shrExact");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@shuffle");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@sizeOf");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@splat");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@reduce");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@src");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@sqrt");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@sin");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@cos");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@tan");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@exp");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@exp2");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@log");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@log2");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@log10");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@abs");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@floor");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@ceil");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@trunc");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@round");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@subWithOverflow");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@tagName");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@This");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@trap");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@truncate");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@EnumLiteral");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@Int");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@Tuple");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@Pointer");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@Fn");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@Struct");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@Union");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@Enum");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@typeInfo");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@typeName");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@TypeOf");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@unionInit");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@Vector");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@volatileCast");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@workGroupId");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@workGroupSize");
                        len += try writeKeywordIfExists(w, line, &i, .builtin, "@workItemId");

                        len += try writeKeywordIfExists(w, line, &i, .boolean, "false");
                        len += try writeKeywordIfExists(w, line, &i, .boolean, "true");

                        len += try writeKeywordIfExists(w, line, &i, .type, "bool");
                        len += try writeKeywordIfExists(w, line, &i, .type, "isize");
                        len += try writeKeywordIfExists(w, line, &i, .type, "usize");
                        len += try writeKeywordIfExists(w, line, &i, .type, "void");

                        if (i < line.len and i == 0 or !std.ascii.isAlphanumeric(line[i - 1])) {
                            // custom numerical types
                            if ((line[i] == 'u' or line[i] == 'i') and
                                i + 1 < line.len and std.ascii.isDigit(line[i + 1]))
                            {
                                len += try changeSyntaxGroup(w, &group, .type);
                                group_index = i;

                                try w.writeByte(line[i]);
                                len += 1;
                                i += 1;
                                while (i < line.len and std.ascii.isDigit(line[i])) : (i += 1) {
                                    len += try parser.printEscapedHtml(line[i], w);
                                }
                                len += try changeSyntaxGroup(w, &group, .plain);
                            }

                            if (std.ascii.isDigit(line[i])) {
                                len += try changeSyntaxGroup(w, &group, .number);
                                group_index = i;
                            }
                        }

                        if (i >= line.len) break;
                    }
                } else if (group == .number and !std.ascii.isDigit(line[i]) and line[i] != '.') {
                    len += try changeSyntaxGroup(w, &group, .plain);
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
            else => len += try parser.printEscapedHtml(line[i], w),
        }
    }

    if (group != .plain) {
        len += try changeSyntaxGroup(w, &group, .plain);
    }

    return len + try w.write("\n");
}

test "crontab" {
    const input =
        \\# this is a good cronjob
        \\*/5 * */2 * * rm -r /home/sam # inline comment
        \\* * * * * echo hello
        \\
    ;
    const output =
        \\<span class="lang-comment"># this is a good cronjob</span>
        \\<span class="lang-section">*/5 * */2 * *</span> <span class="lang-builtin">rm</span> -r /home/sam <span class="lang-comment"># inline comment</span>
        \\<span class="lang-section">* * * * *</span> <span class="lang-builtin">echo</span> hello
        \\
    ;
    try th.expectCodeHighlight(.crontab, input, output);
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

test "json" {
    const input =
        \\{
        \\  "property": "value",
        \\  "nested": {
        \\    "prop2": 0,
        \\    "prop3": "val3 is \"hi\""
        \\  },
        \\  "arr": [
        \\    "1",
        \\    "2"
        \\  ],
        \\  "arrNum": [ 1, 2, 3.0 ],
        \\  "inline": [ "array" ]
        \\}
        \\
    ;
    const output =
        \\{
        \\<span class="lang-attr">  "property"</span>: <span class="lang-string">"value"</span>,
        \\<span class="lang-attr">  "nested"</span>: {
        \\<span class="lang-attr">    "prop2"</span>: <span class="lang-number">0</span>,
        \\<span class="lang-attr">    "prop3"</span>: <span class="lang-string">"val3 is \"hi\""</span>
        \\  },
        \\<span class="lang-attr">  "arr"</span>: [
        \\    <span class="lang-string">"1"</span>,
        \\    <span class="lang-string">"2"</span>
        \\  ],
        \\<span class="lang-attr">  "arrNum"</span>: [ <span class="lang-number">1</span>, <span class="lang-number">2</span>, <span class="lang-number">3.0</span> ],
        \\<span class="lang-attr">  "inline"</span>: [ <span class="lang-string">"array"</span> ]
        \\}
        \\
    ;
    try th.expectCodeHighlight(.json, input, output);
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

test "zig" {
    const input =
        \\//! doc comment
        \\
        \\/// does something cool
        \\fn doSomething(r: *Reader) Reader.DelimiterError![]u8 {
        \\    const result = r.peekDelimiterInclusive('\n') catch |err| switch (err) {
        \\        Reader.DelimiterError.EndOfStream, Reader.DelimiterError.StreamTooLong => {
        \\            const remaining = r.buffer[r.seek..r.end]; // inline
        \\            if (remaining.len == 0) return error.EndOfStream;
        \\            r.toss(remaining.len);
        \\            return remaining;
        \\        },
        \\        else => |e| return e,
        \\    };
        \\    r.toss(result.len);
        \\    var j: isize = 1;
        \\    var k: i7 = 0;
        \\    const is_programming = true;
        \\
        \\    if (result.len > 1 and result[result.len - 2] == '\r') {
        \\        @branchHint(.cold);
        \\        return result[0 .. result.len - 2];
        \\    }
        \\
        \\    var i: usize = 0;
        \\    while (i < 3): (i += 1) {
        \\        std.log.debug("Hello", .{});
        \\    }
        \\
        \\    return result[0 .. result.len - 1];
        \\}
        \\
    ;
    const output =
        \\<span class="lang-comment">//! doc comment</span>
        \\
        \\<span class="lang-comment">/// does something cool</span>
        \\<span class="lang-keyword">fn</span> doSomething(r: *Reader) Reader.DelimiterError![]<span class="lang-type">u8</span> {
        \\    <span class="lang-keyword">const</span> result = r.peekDelimiterInclusive(<span class="lang-string">'\n'</span>) <span class="lang-keyword">catch</span> |err| <span class="lang-keyword">switch</span> (err) {
        \\        Reader.DelimiterError.EndOfStream, Reader.DelimiterError.StreamTooLong =&gt; {
        \\            <span class="lang-keyword">const</span> remaining = r.buffer[r.seek..r.end]; <span class="lang-comment">// inline</span>
        \\            <span class="lang-keyword">if</span> (remaining.len == <span class="lang-number">0</span>) <span class="lang-keyword">return</span> <span class="lang-keyword">error</span>.EndOfStream;
        \\            r.toss(remaining.len);
        \\            <span class="lang-keyword">return</span> remaining;
        \\        },
        \\        <span class="lang-keyword">else</span> =&gt; |e| <span class="lang-keyword">return</span> e,
        \\    };
        \\    r.toss(result.len);
        \\    <span class="lang-keyword">var</span> j: <span class="lang-type">isize</span> = <span class="lang-number">1</span>;
        \\    <span class="lang-keyword">var</span> k: <span class="lang-type">i7</span> = <span class="lang-number">0</span>;
        \\    <span class="lang-keyword">const</span> is_programming = <span class="lang-boolean">true</span>;
        \\
        \\    <span class="lang-keyword">if</span> (result.len &gt; <span class="lang-number">1</span> <span class="lang-keyword">and</span> result[result.len - <span class="lang-number">2</span>] == <span class="lang-string">'\r'</span>) {
        \\        <span class="lang-builtin">@branchHint</span>(.cold);
        \\        <span class="lang-keyword">return</span> result[<span class="lang-number">0</span> .. result.len - <span class="lang-number">2</span>];
        \\    }
        \\
        \\    <span class="lang-keyword">var</span> i: <span class="lang-type">usize</span> = <span class="lang-number">0</span>;
        \\    <span class="lang-keyword">while</span> (i &lt; <span class="lang-number">3</span>): (i += <span class="lang-number">1</span>) {
        \\        std.log.debug(<span class="lang-string">"Hello"</span>, .{});
        \\    }
        \\
        \\    <span class="lang-keyword">return</span> result[<span class="lang-number">0</span> .. result.len - <span class="lang-number">1</span>];
        \\}
        \\
    ;
    try th.expectCodeHighlight(.zig, input, output);
}
