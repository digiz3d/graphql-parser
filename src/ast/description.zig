const std = @import("std");
const testing = std.testing;
const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const ParseError = @import("../parser.zig").ParseError;

pub fn parseOptionalDescription(parser: *Parser) ParseError!?[]const u8 {
    const firstToken = parser.peekNextToken() orelse return null;
    if (firstToken.tag != Token.Tag.string_literal and firstToken.tag != Token.Tag.string_literal_block) return null;

    const description = try parser.consumeToken(firstToken.tag);
    return try parser.getTokenValue(description);
}

test "parseOptionalDescription" {
    const buffer = "\"some description\"";
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();
    const description = try parseOptionalDescription(&parser);
    defer testing.allocator.free(description.?);
    try testing.expectEqualStrings("\"some description\"", description.?);
}
