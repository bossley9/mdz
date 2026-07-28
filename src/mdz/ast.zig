const std = @import("std");

pub const Block = enum(u4) {
    // line blocks
    aside,
    block_quote,
    unordered_list,
    ordered_list,
    // leaf blocks
    paragraph,
    paragraph_hidden,
    code_block,
    pre_block,
    html_block,
    footnote_reference,
    table,
};

const FlagField = std.enums.EnumSet(enum {
    is_em,
    is_strong,
    is_code,
    is_link,
    is_footnote_citation,
    is_img,
    is_strike,
    is_del,
    is_ins,
    is_mark,
});

pub const CodeLanguage = enum {
    crontab,
    css,
    diff,
    go,
    html,
    ini,
    javascript,
    js,
    json,
    jsx,
    lua,
    patch,
    plaintext,
    ruby,
    sh,
    ts,
    tsx,
    vim,
    yaml,
    zig,
};

pub const BlockState = struct {
    /// stored as a dictionary where the index represents the numeric
    /// citation symbol and the value represents the number of citations
    footnotes: [64]u8,
    items: std.ArrayList(Block),
    flags: FlagField,
    lang: CodeLanguage,

    pub fn init(stack_buffer: []Block) BlockState {
        var state = BlockState{
            .items = .initBuffer(stack_buffer),
            .flags = FlagField.init(.{}),
            .footnotes = undefined,
            .lang = .plaintext,
        };
        @memset(&state.footnotes, 0);
        return state;
    }
};
