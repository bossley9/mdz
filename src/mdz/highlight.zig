const std = @import("std");
const ast = @import("./ast.zig");
const parser = @import("./parser.zig");
const th = @import("./test_helpers.zig");

const Io = std.Io;

const SyntaxGroup = enum {
    addition,
    attr,
    literal,
    comment,
    deletion,
    function,
    meta,
    number,
    plain,
    section,
    string,
    tag,
    type,
};

/// Return true if the characters ahead match the pattern.
fn lookAheadHas(line: []u8, i: usize, pattern: []const u8) bool {
    if (i + pattern.len > line.len) return false;
    return std.mem.eql(u8, line[i .. i + pattern.len], pattern);
}

/// Return true if the characters behind match the pattern.
/// Does not check if the pattern can exist.
fn lookBehindHas(line: []u8, i: usize, pattern: []const u8) bool {
    return std.mem.eql(u8, line[i - pattern.len + 1 .. i + 1], pattern);
}
fn lookBehindHasUnescaped(line: []u8, i: usize, pattern: u8) bool {
    return line[i - 1] != '\\' and line[i] == pattern;
}

/// Format and print word if it exists. Otherwise, try next word.
fn writeWordIfExists(
    w: *Io.Writer,
    line: []u8,
    i: *usize,
    kind: enum { builtin, function, keyword, literal, type },
    words: [][]const u8,
) Io.Writer.Error!usize {
    // start does not match
    if (i.* != 0 and std.ascii.isAlphanumeric(line[i.* - 1])) return 0;

    for (words) |word| {
        if (
        // pattern does not match
        !lookAheadHas(line, i.*, word) or
            // end does not match
            (i.* + word.len != line.len and std.ascii.isAlphanumeric(line[i.* + word.len]))) continue;

        i.* += word.len;
        const prefix = switch (kind) {
            .builtin => "<span class=\"lang-built_in\">",
            .function => "<span class=\"lang-title\">",
            .keyword => "<span class=\"lang-keyword\">",
            .literal => "<span class=\"lang-literal\">",
            .type => "<span class=\"lang-type\">",
        };
        try w.print("{s}{s}</span>", .{ prefix, word });
        return prefix.len + word.len + 7;
    }
    // no match found
    return 0;
}

fn changeSyntaxGroup(w: *Io.Writer, current_group: *SyntaxGroup, new_group: SyntaxGroup) Io.Writer.Error!usize {
    current_group.* = new_group;
    return switch (new_group) {
        .addition => try w.write("<span class=\"lang-addition\">"),
        .attr => try w.write("<span class=\"lang-attr\">"),
        .comment => try w.write("<span class=\"lang-comment\">"),
        .deletion => try w.write("<span class=\"lang-deletion\">"),
        .function => try w.write("<span class=\"lang-title\">"),
        .literal => try w.write("<span class=\"lang-literal\">"),
        .meta => try w.write("<span class=\"lang-meta\">"),
        .number => try w.write("<span class=\"lang-number\">"),
        .plain => try w.write("</span>"),
        .section => try w.write("<span class=\"lang-section\">"),
        .string => try w.write("<span class=\"lang-string\">"),
        .tag => try w.write("<span class=\"lang-tag\">"),
        .type => try w.write("<span class=\"lang-type\">"),
    };
}

var go_builtins = [_][]const u8{ "append", "make" };
var go_keywords = [_][]const u8{ "case", "continue", "defer", "for", "func", "go", "import", "package", "range", "return", "select" };
var go_literals = [_][]const u8{"nil"};
var go_types = [_][]const u8{ "chan", "error" };
var js_functions = [_][]const u8{ "Boolean", "Number", "Promise", "String" };
var js_keywords = [_][]const u8{ "async", "await", "break", "catch", "class", "const", "constructor", "continue", "delete", "do", "else", "export", "extends", "for", "function", "from", "if", "import", "in", "instanceof", "let", "new", "of", "return", "static", "super", "switch", "this", "throw", "try", "type", "typeof", "using", "var", "void", "while", "with", "yield" };
var js_literals = [_][]const u8{ "document", "false", "globalThis", "Infinity", "NaN", "null", "undefined", "true", "window" };
var js_types = [_][]const u8{ "Awaited", "any", "as", "boolean", "is", "NonNullable", "never", "number", "Omit", "object", "Parameters", "Partial", "Pick", "Record", "Required", "ReturnType", "readonly", "string", "unknown" };
var lua_builtins = [_][]const u8{ "false", "nil", "true" };
var lua_keywords = [_][]const u8{ "break", "do", "end", "elsif", "else", "for", "function", "if", "local", "repeat", "return", "then", "until", "while" };
var sh_builtins = [_][]const u8{ "cd", "chgrp", "chmod", "chown", "cp", "echo", "mkdir", "mv", "printf", "rm" };
var sh_keywords = [_][]const u8{ "fi", "if", "then" };
var vim_keywords = [_][]const u8{ "let", "set" };
var zig_builtins = [_][]const u8{ "@addrSpaceCast", "@addWithOverflow", "@alignCast", "@alignOf", "@as", "@atomicLoad", "@atomicRmw", "@atomicStore", "@bitCast", "@bitOffsetOf", "@bitSizeOf", "@branchHint", "@breakpoint", "@mulAdd", "@byteSwap", "@bitReverse", "@offsetOf", "@call", "@cDefine", "@cImport", "@cInclude", "@clz", "@cmpxchgStrong", "@cmpxchgWeak", "@compileError", "@compileLog", "@constCast", "@ctz", "@cUndef", "@cVaArg", "@cVaCopy", "@cVaEnd", "@cVaStart", "@divExact", "@divFloor", "@divTrunc", "@embedFile", "@enumFromInt", "@errorFromInt", "@errorName", "@errorReturnTrace", "@errorCast", "@export", "@extern", "@field", "@fieldParentPtr", "@FieldType", "@floatCast", "@floatFromInt", "@frameAddress", "@hasDecl", "@hasField", "@import", "@inComptime", "@intCast", "@intFromBool", "@intFromEnum", "@intFromError", "@intFromFloat", "@intFromPtr", "@max", "@memcpy", "@memset", "@memmove", "@min", "@wasmMemorySize", "@wasmMemoryGrow", "@mod", "@mulWithOverflow", "@panic", "@popCount", "@prefetch", "@ptrCast", "@ptrFromInt", "@rem", "@returnAddress", "@select", "@setEvalBranchQuota", "@setFloatMode", "@setRuntimeSafety", "@shlExact", "@shlWithOverflow", "@shrExact", "@shuffle", "@sizeOf", "@splat", "@reduce", "@src", "@sqrt", "@sin", "@cos", "@tan", "@exp", "@exp2", "@log", "@log2", "@log10", "@abs", "@floor", "@ceil", "@trunc", "@round", "@subWithOverflow", "@tagName", "@This", "@trap", "@truncate", "@EnumLiteral", "@Int", "@Tuple", "@Pointer", "@Fn", "@Struct", "@Union", "@Enum", "@typeInfo", "@typeName", "@TypeOf", "@unionInit", "@Vector", "@volatileCast", "@workGroupId", "@workGroupSize", "@workItemId" };
var zig_keywords = [_][]const u8{ "addrspace", "align", "allowzero", "and", "anyframe", "anytype", "asm", "break", "callconv", "catch", "comptime", "const", "continue", "defer", "else", "enum", "errdefer", "error", "export", "extern", "fn", "for", "if", "inline", "noalias", "nosuspend", "noinline", "opaque", "or", "orelse", "packed", "pub", "resume", "return", "linksection", "struct", "suspend", "switch", "test", "threadlocal", "try", "union", "unreachable", "var", "volatile", "while" };
var zig_literals = [_][]const u8{ "false", "true" };
var zig_types = [_][]const u8{ "bool", "isize", "usize", "void" };

const css_open_bracket = " {";
const diff_meta = "@@";
const html_open_comment = "<!--";

/// Rudimentary code highlighter that operates on individual lines of code
/// using basic forward and backward lookup
pub fn highlight_code_line(w: *Io.Writer, line: []u8, lang: ast.CodeLanguage) Io.Writer.Error!usize {
    var len: usize = 0;
    var i: usize = 0;
    var group: SyntaxGroup = .plain;
    var group_index: usize = 0;

    var string_char: u8 = '\'';
    const has_colon = (std.mem.findScalar(u8, line, ':') orelse 0) > 0;
    var has_bracket: ?bool = null;
    var in_tag = false;
    var num_spaces: usize = 0;

    while (i < line.len) : (i += 1) {
        switch (lang) {
            .css => {
                has_bracket = has_bracket orelse ((std.mem.findScalar(u8, line, '{') orelse 0) > 0);
                if (i == 0 and has_bracket.?) {
                    len += try changeSyntaxGroup(w, &group, .attr);
                    group_index = i;
                } else if (i != group_index and lookAheadHas(line, i, css_open_bracket)) {
                    len += try changeSyntaxGroup(w, &group, .plain);
                    len += try w.write(css_open_bracket);
                    i += css_open_bracket.len - 1;
                    continue;
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
                    } else if (lookAheadHas(line, i, diff_meta)) {
                        len += try changeSyntaxGroup(w, &group, .meta);
                        group_index = i;
                        len += try w.write(diff_meta);
                        i += diff_meta.len - 1;
                        continue;
                    }
                }

                len += try parser.printEscapedHtml(line[i], w);

                if (group == .meta and i != group_index and lookBehindHas(line, i, diff_meta)) {
                    len += try changeSyntaxGroup(w, &group, .plain);
                }
            },
            .go => {
                if (group == .plain) {
                    if (lookAheadHas(line, i, "//")) {
                        len += try changeSyntaxGroup(w, &group, .comment);
                        group_index = i;
                    } else if (line[i] == '"') {
                        len += try changeSyntaxGroup(w, &group, .string);
                        string_char = line[i];
                        group_index = i;
                    } else if (i >= 5 and std.mem.eql(u8, line[i - 5 .. i], "func ")) {
                        len += try changeSyntaxGroup(w, &group, .function);
                        group_index = i;
                    } else {
                        len += try writeWordIfExists(w, line, &i, .builtin, &go_builtins);
                        len += try writeWordIfExists(w, line, &i, .keyword, &go_keywords);
                        len += try writeWordIfExists(w, line, &i, .literal, &go_literals);
                        len += try writeWordIfExists(w, line, &i, .type, &go_types);

                        if (i >= line.len) break;
                    }
                } else if (group == .function and line[i] == '(') {
                    len += try changeSyntaxGroup(w, &group, .plain);
                }
                len += try parser.printEscapedHtml(line[i], w);
                if (group == .string and i != group_index and lookBehindHasUnescaped(line, i, string_char)) {
                    len += try changeSyntaxGroup(w, &group, .plain);
                }
            },
            .html => {
                if (group == .plain) {
                    if (lookAheadHas(line, i, html_open_comment)) {
                        len += try changeSyntaxGroup(w, &group, .comment);
                        group_index = i;
                        len += try w.write("&lt;!--");
                        i += html_open_comment.len - 1;
                        continue;
                    } else if (line[i] == '<') {
                        len += try parser.printEscapedHtml(line[i], w);
                        i += 1;

                        if (i < line.len and line[i] == '/') {
                            len += try parser.printEscapedHtml(line[i], w);
                            i += 1;
                        }

                        in_tag = true;
                        len += try changeSyntaxGroup(w, &group, .tag);
                        group_index = i;
                    } else if (in_tag and line[i] == '"') {
                        len += try changeSyntaxGroup(w, &group, .string);
                        string_char = line[i];
                        group_index = i;
                    } else if (in_tag and i > 0 and line[i - 1] == '=') {
                        len += try changeSyntaxGroup(w, &group, .string);
                        string_char = ' ';
                        group_index = i;
                    } else if (in_tag and std.ascii.isAlphabetic(line[i])) {
                        len += try changeSyntaxGroup(w, &group, .attr);
                        group_index = i;
                    }
                } else if (group == .tag or group == .string) {
                    if (line[i] == '>') {
                        len += try changeSyntaxGroup(w, &group, .plain);
                        in_tag = false;
                    } else if (line[i] == ' ' and group != .string) {
                        len += try changeSyntaxGroup(w, &group, .plain);
                    }
                } else if (group == .attr) {
                    if (line[i] == '=' or line[i] == ' ') {
                        len += try changeSyntaxGroup(w, &group, .plain);
                    }
                }
                len += try parser.printEscapedHtml(line[i], w);
                if (group == .string and i != group_index and lookBehindHasUnescaped(line, i, string_char)) {
                    len += try changeSyntaxGroup(w, &group, .plain);
                } else if (group == .comment and lookBehindHas(line, i, "-->")) {
                    len += try changeSyntaxGroup(w, &group, .plain);
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
                        len += try changeSyntaxGroup(w, &group, .string);
                        string_char = line[i];
                        group_index = i;
                    } else if (line[i] == '#') {
                        len += try changeSyntaxGroup(w, &group, .comment);
                        group_index = i;
                    }
                }

                if (group == .attr and i != group_index and lookAheadHas(line, i, " =")) {
                    len += try changeSyntaxGroup(w, &group, .plain);
                }

                len += try parser.printEscapedHtml(line[i], w);

                if (group == .string and i != group_index and lookBehindHasUnescaped(line, i, string_char)) {
                    len += try changeSyntaxGroup(w, &group, .plain);
                }
            },
            .js, .jsx, .ts, .tsx => {
                if (group == .plain) {
                    if (lookAheadHas(line, i, "//")) {
                        len += try changeSyntaxGroup(w, &group, .comment);
                        group_index = i;
                    } else if (line[i] == '\'' or line[i] == '"' or line[i] == '`') {
                        len += try changeSyntaxGroup(w, &group, .string);
                        string_char = line[i];
                        group_index = i;
                    } else if ((i == 0 or !std.ascii.isAlphanumeric(line[i - 1])) and std.ascii.isDigit(line[i])) {
                        len += try changeSyntaxGroup(w, &group, .number);
                        group_index = i;
                    } else if (std.ascii.isAlphabetic(line[i]) and i >= 9 and std.mem.eql(u8, line[i - 9 .. i], "function ")) {
                        len += try changeSyntaxGroup(w, &group, .function);
                        group_index = i;
                    } else {
                        len += try writeWordIfExists(w, line, &i, .function, &js_functions);
                        len += try writeWordIfExists(w, line, &i, .keyword, &js_keywords);
                        len += try writeWordIfExists(w, line, &i, .literal, &js_literals);
                        len += try writeWordIfExists(w, line, &i, .type, &js_types);

                        if (i >= line.len) break;
                    }
                } else if (group == .number and !std.ascii.isDigit(line[i]) and line[i] != '.') {
                    len += try changeSyntaxGroup(w, &group, .plain);
                } else if (group == .function and line[i] == '(') {
                    len += try changeSyntaxGroup(w, &group, .plain);
                }

                len += try parser.printEscapedHtml(line[i], w);

                if (group == .string and i != group_index and lookBehindHasUnescaped(line, i, string_char)) {
                    len += try changeSyntaxGroup(w, &group, .plain);
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
                        len += try changeSyntaxGroup(w, &group, .string);
                        string_char = line[i];
                        group_index = i;
                    } else if (std.ascii.isDigit(line[i])) {
                        len += try changeSyntaxGroup(w, &group, .number);
                        group_index = i;
                    }
                }
                len += try parser.printEscapedHtml(line[i], w);
                if (group == .string and i != group_index and lookBehindHasUnescaped(line, i, string_char)) {
                    len += try changeSyntaxGroup(w, &group, .plain);
                }
            },
            .lua => {
                if (group == .plain) {
                    if (lookAheadHas(line, i, "--")) {
                        len += try changeSyntaxGroup(w, &group, .comment);
                        group_index = i;
                    } else if (line[i] == '"') {
                        len += try changeSyntaxGroup(w, &group, .string);
                        string_char = line[i];
                        group_index = i;
                    } else {
                        len += try writeWordIfExists(w, line, &i, .builtin, &lua_builtins);
                        len += try writeWordIfExists(w, line, &i, .keyword, &lua_keywords);

                        if (i >= line.len) break;
                    }
                }

                len += try parser.printEscapedHtml(line[i], w);

                if (group == .string and i != group_index and lookBehindHasUnescaped(line, i, string_char)) {
                    len += try changeSyntaxGroup(w, &group, .plain);
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
                    } else if (line[i] == '\'' or line[i] == '"') {
                        len += try changeSyntaxGroup(w, &group, .string);
                        string_char = line[i];
                        group_index = i;
                    } else {
                        len += try writeWordIfExists(w, line, &i, .builtin, &sh_builtins);
                        len += try writeWordIfExists(w, line, &i, .keyword, &sh_keywords);

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

                if (group == .string and i != group_index and lookBehindHasUnescaped(line, i, string_char)) {
                    len += try changeSyntaxGroup(w, &group, .plain);
                }
            },
            .vim => {
                if (group == .plain) {
                    if (lookAheadHas(line, i, "\" ")) {
                        len += try changeSyntaxGroup(w, &group, .comment);
                    } else if (line[i] == '\'' or line[i] == '"') {
                        len += try changeSyntaxGroup(w, &group, .string);
                        string_char = line[i];
                        group_index = i;
                    } else {
                        len += try writeWordIfExists(w, line, &i, .keyword, &vim_keywords);

                        if (i >= line.len) break;
                    }
                }
                len += try parser.printEscapedHtml(line[i], w);
                if (group == .string and i != group_index and lookBehindHasUnescaped(line, i, string_char)) {
                    len += try changeSyntaxGroup(w, &group, .plain);
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
                    len += try changeSyntaxGroup(w, &group, .string);
                    group_index = i;
                }

                len += try parser.printEscapedHtml(line[i], w);

                if (group == .attr and i != group_index and lookBehindHas(line, i, ":") and i + 1 < line.len) {
                    len += try changeSyntaxGroup(w, &group, .plain);
                    len += try changeSyntaxGroup(w, &group, .string);
                    group_index = i;
                }
            },
            .zig => {
                if (group == .plain) {
                    if (lookAheadHas(line, i, "//")) {
                        len += try changeSyntaxGroup(w, &group, .comment);
                        group_index = i;
                    } else if (line[i] == '\'' or line[i] == '"') {
                        len += try changeSyntaxGroup(w, &group, .string);
                        string_char = line[i];
                        group_index = i;
                    } else if (std.ascii.isAlphabetic(line[i]) and i >= 3 and std.mem.eql(u8, line[i - 3 .. i], "fn ")) {
                        len += try changeSyntaxGroup(w, &group, .function);
                        group_index = i;
                    } else {
                        len += try writeWordIfExists(w, line, &i, .builtin, &zig_builtins);
                        len += try writeWordIfExists(w, line, &i, .keyword, &zig_keywords);
                        len += try writeWordIfExists(w, line, &i, .literal, &zig_literals);
                        len += try writeWordIfExists(w, line, &i, .type, &zig_types);

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
                } else if (group == .function and line[i] == '(') {
                    len += try changeSyntaxGroup(w, &group, .plain);
                }

                len += try parser.printEscapedHtml(line[i], w);

                if (group == .string and i != group_index and lookBehindHasUnescaped(line, i, string_char)) {
                    len += try changeSyntaxGroup(w, &group, .plain);
                }
            },
            .plaintext => len += try parser.printEscapedHtml(line[i], w),
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
        \\<span class="lang-section">*/5 * */2 * *</span> <span class="lang-built_in">rm</span> -r /home/sam <span class="lang-comment"># inline comment</span>
        \\<span class="lang-section">* * * * *</span> <span class="lang-built_in">echo</span> hello
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

test "go" {
    const input =
        \\package main
        \\
        \\import "fmt"
        \\
        \\// comment
        \\func main() {
        \\    arr := make([]string, 4)
        \\    arr = append(arr, "Hello")
        \\
        \\    i := 1
        \\    for i <= 3 {
        \\        fmt.Println(i) // inline comment
        \\        i = i + 1
        \\    }
        \\
        \\    for n := range 6 {
        \\        if n%2 == 0 {
        \\            continue
        \\        }
        \\        fmt.Println(n)
        \\    }
        \\}
        \\
    ;
    const output =
        \\<span class="lang-keyword">package</span> main
        \\
        \\<span class="lang-keyword">import</span> <span class="lang-string">"fmt"</span>
        \\
        \\<span class="lang-comment">// comment</span>
        \\<span class="lang-keyword">func</span> <span class="lang-title">main</span>() {
        \\    arr := <span class="lang-built_in">make</span>([]string, 4)
        \\    arr = <span class="lang-built_in">append</span>(arr, <span class="lang-string">"Hello"</span>)
        \\
        \\    i := 1
        \\    <span class="lang-keyword">for</span> i &lt;= 3 {
        \\        fmt.Println(i) <span class="lang-comment">// inline comment</span>
        \\        i = i + 1
        \\    }
        \\
        \\    <span class="lang-keyword">for</span> n := <span class="lang-keyword">range</span> 6 {
        \\        if n%2 == 0 {
        \\            <span class="lang-keyword">continue</span>
        \\        }
        \\        fmt.Println(n)
        \\    }
        \\}
        \\
    ;
    try th.expectCodeHighlight(.go, input, output);
}

test "html" {
    const input =
        \\<h1 class="test data" data-selected id=123>Title</h1>
        \\<style>
        \\  div {
        \\    background: red;
        \\  }
        \\</style>
        \\<!-- html comment --><span>content</span>
        \\<div>
        \\  <web-component></web-component>
        \\  <div>
        \\    <p>Hello</p>
        \\    <p>World</p>
        \\  </div>
        \\</div>
        \\
    ;
    const output =
        \\&lt;<span class="lang-tag">h1</span> <span class="lang-attr">class</span>=<span class="lang-string">"test data"</span> <span class="lang-attr">data-selected</span> <span class="lang-attr">id</span>=<span class="lang-string">123</span>&gt;Title&lt;/<span class="lang-tag">h1</span>&gt;
        \\&lt;<span class="lang-tag">style</span>&gt;
        \\  div {
        \\    background: red;
        \\  }
        \\&lt;/<span class="lang-tag">style</span>&gt;
        \\<span class="lang-comment">&lt;!-- html comment --&gt;</span>&lt;<span class="lang-tag">span</span>&gt;content&lt;/<span class="lang-tag">span</span>&gt;
        \\&lt;<span class="lang-tag">div</span>&gt;
        \\  &lt;<span class="lang-tag">web-component</span>&gt;&lt;/<span class="lang-tag">web-component</span>&gt;
        \\  &lt;<span class="lang-tag">div</span>&gt;
        \\    &lt;<span class="lang-tag">p</span>&gt;Hello&lt;/<span class="lang-tag">p</span>&gt;
        \\    &lt;<span class="lang-tag">p</span>&gt;World&lt;/<span class="lang-tag">p</span>&gt;
        \\  &lt;/<span class="lang-tag">div</span>&gt;
        \\&lt;/<span class="lang-tag">div</span>&gt;
        \\
    ;
    try th.expectCodeHighlight(.html, input, output);
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

test "js, jsx, ts, tsx" {
    const input =
        \\import { myMod } from 'mod';
        \\// comment
        \\const x = Number("34");
        \\
        \\export function useVal() {
        \\  return useQuery({
        \\    queryKey: [ 'val' ],
        \\    queryFn: () => fetch(`api/${4}`),
        \\  })
        \\}
        \\const q = "hello \"sam\"";
        \\
        \\function hello() {
        \\    return null;
        \\}
        \\
        \\let y2 = false;
        \\while (!y2) {
        \\    x++;
        \\    if (x === undefined || x === null || x > 70) {
        \\        y2 = true;
        \\    }
        \\}
        \\
    ;
    const output =
        \\<span class="lang-keyword">import</span> { myMod } <span class="lang-keyword">from</span> <span class="lang-string">'mod'</span>;
        \\<span class="lang-comment">// comment</span>
        \\<span class="lang-keyword">const</span> x = <span class="lang-title">Number</span>(<span class="lang-string">"34"</span>);
        \\
        \\<span class="lang-keyword">export</span> <span class="lang-keyword">function</span> <span class="lang-title">useVal</span>() {
        \\  <span class="lang-keyword">return</span> useQuery({
        \\    queryKey: [ <span class="lang-string">'val'</span> ],
        \\    queryFn: () =&gt; fetch(<span class="lang-string">`api/${4}`</span>),
        \\  })
        \\}
        \\<span class="lang-keyword">const</span> q = <span class="lang-string">"hello \"sam\""</span>;
        \\
        \\<span class="lang-keyword">function</span> <span class="lang-title">hello</span>() {
        \\    <span class="lang-keyword">return</span> <span class="lang-literal">null</span>;
        \\}
        \\
        \\<span class="lang-keyword">let</span> y2 = <span class="lang-literal">false</span>;
        \\<span class="lang-keyword">while</span> (!y2) {
        \\    x++;
        \\    <span class="lang-keyword">if</span> (x === <span class="lang-literal">undefined</span> || x === <span class="lang-literal">null</span> || x &gt; <span class="lang-number">70</span>) {
        \\        y2 = <span class="lang-literal">true</span>;
        \\    }
        \\}
        \\
    ;
    try th.expectCodeHighlight(.js, input, output);
    try th.expectCodeHighlight(.jsx, input, output);
    try th.expectCodeHighlight(.ts, input, output);
    try th.expectCodeHighlight(.tsx, input, output);
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

test "lua" {
    const input =
        \\-- this is a comment
        \\local x = true -- inline comment
        \\function()
        \\  if x then
        \\    print("hello, " .. "john")
        \\    vim.fn.mkdir("test", "p")
        \\    return 4
        \\  end
        \\end
        \\
    ;
    const output =
        \\<span class="lang-comment">-- this is a comment</span>
        \\<span class="lang-keyword">local</span> x = <span class="lang-built_in">true</span> <span class="lang-comment">-- inline comment</span>
        \\<span class="lang-keyword">function</span>()
        \\  <span class="lang-keyword">if</span> x <span class="lang-keyword">then</span>
        \\    print(<span class="lang-string">"hello, "</span> .. <span class="lang-string">"john"</span>)
        \\    vim.fn.mkdir(<span class="lang-string">"test"</span>, <span class="lang-string">"p"</span>)
        \\    <span class="lang-keyword">return</span> 4
        \\  <span class="lang-keyword">end</span>
        \\<span class="lang-keyword">end</span>
        \\
    ;
    try th.expectCodeHighlight(.lua, input, output);
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
        \\<span class="lang-built_in">echo</span> <span class="lang-string">"Hello 'john'!"</span>
        \\<span class="lang-built_in">echo</span> <span class="lang-string">'another \' string'</span> <span class="lang-comment"># trailing comment</span>
        \\ifconfig
        \\
        \\<span class="lang-keyword">if</span> something; <span class="lang-keyword">then</span>
        \\  <span class="lang-built_in">rm</span> -rf /
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
        \\<span class="lang-keyword">fn</span> <span class="lang-title">doSomething</span>(r: *Reader) Reader.DelimiterError![]<span class="lang-type">u8</span> {
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
        \\    <span class="lang-keyword">const</span> is_programming = <span class="lang-literal">true</span>;
        \\
        \\    <span class="lang-keyword">if</span> (result.len &gt; <span class="lang-number">1</span> <span class="lang-keyword">and</span> result[result.len - <span class="lang-number">2</span>] == <span class="lang-string">'\r'</span>) {
        \\        <span class="lang-built_in">@branchHint</span>(.cold);
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
