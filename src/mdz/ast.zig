const std = @import("std");

pub const Block = enum(u3) {
    // line blocks
    block_quote,
    unordered_list,
    ordered_list,
    // leaf blocks
    paragraph,
    paragraph_hidden,
    code_block,
    html_block,
};

const Flags = packed struct {
    is_em: bool = false,
    is_strong: bool = false,
    is_code: bool = false,
};

const max_stack_len = 12;

pub const StackError = error{BlockStackOverflow};

pub const BlockState = struct {
    items: [max_stack_len]?Block,
    len: usize,
    flags: Flags,

    pub fn init() BlockState {
        var state = BlockState{
            .items = undefined,
            .len = 0,
            .flags = Flags{},
        };
        @memset(&state.items, null);
        return state;
    }

    /// Push the provided block to the stack. The stack must have
    /// available capacity.
    pub fn push(self: *BlockState, block: Block) StackError!void {
        if (self.len == max_stack_len) {
            @branchHint(.cold);
            return StackError.BlockStackOverflow;
        }

        self.items[self.len] = block;
        self.len += 1;
    }
};
