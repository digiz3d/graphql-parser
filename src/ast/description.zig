const std = @import("std");
const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const ParseError = @import("../parser.zig").ParseError;

pub fn parseOptionalDescription(parser: *Parser, tokens: []Token) ParseError!?[]const u8 {
    const firstToken = parser.peekNextToken(tokens) orelse return null;
    if (firstToken.tag != Token.Tag.string_literal and firstToken.tag != Token.Tag.string_literal_block) return null;

    const description = try parser.consumeToken(tokens, firstToken.tag);
    return try parser.getTokenValue(description);
}
