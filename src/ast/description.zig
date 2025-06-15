const std = @import("std");
const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const ParseError = @import("../parser.zig").ParseError;
const Allocator = std.mem.Allocator;

pub fn parseOptionalDescription(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError!?[]const u8 {
    const firstToken = parser.peekNextToken(tokens) orelse return null;
    if (firstToken.tag != Token.Tag.string_literal and firstToken.tag != Token.Tag.string_literal_block) return null;

    const descriptionToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    return try parser.getTokenValue(descriptionToken, allocator);
}
