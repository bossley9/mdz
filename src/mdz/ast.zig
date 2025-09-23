const std = @import("std");

pub const Block = enum(u2) {
    nil = 0,
    // line blocks
    block_quote,
    paragraph,
};

const max_stack_len = 16;

pub const BlockStack = struct {
    items: [max_stack_len]Block,
    len: usize,
};

pub const StackError = error{BlockStackOverflow};

/// Push the provided block to the stack. The block cannot be nil and
/// the stack must have space.
pub fn stackPush(stack: *BlockStack, block: Block) StackError!void {
    std.debug.assert(block != .nil);

    if (stack.len == max_stack_len) {
        @branchHint(.cold);
        return StackError.BlockStackOverflow;
    }

    stack.items[stack.len] = block;
    stack.len += 1;
}

/// Pop the last block from the stack. The stack must have at least
/// one item.
pub fn stackPop(stack: *BlockStack) ?Block {
    if (stack.len == 0) {
        return null;
    }

    const value = stack.items[stack.len - 1];

    stack.items[stack.len - 1] = .nil;
    stack.len -= 1;

    return value;
}
