const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const Tokenizer = @import("tokenizer.zig");
const printTokens = @import("tokenizer.zig").printTokens;

pub const Parser = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) Parser {
        return Parser{ .allocator = allocator };
    }

    pub fn parse(self: *Parser, buffer: [:0]const u8) !void {
        var tokenizer = Tokenizer.Tokenizer.init(buffer);
        const tokens = try tokenizer.getAllTokens(self.allocator);

        // TODO: make sense of the tokens
        printTokens(tokens, buffer);
    }
};
