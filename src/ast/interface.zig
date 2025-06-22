const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("../parser.zig");
const Parser = p.Parser;
const ParseError = p.ParseError;

const t = @import("../tokenizer.zig");
const Tokenizer = t.Tokenizer;
const Token = t.Token;
const strEq = @import("../utils/utils.zig").strEq;

const Type = @import("type.zig").Type;
const parseNamedType = @import("type.zig").parseNamedType;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

pub const Interface = struct {
    allocator: Allocator,
    type: Type,

    pub fn printAST(self: Interface, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);

        const typeStr = self.type.getPrintableString(self.allocator);
        defer self.allocator.free(typeStr);
        std.debug.print("{s}- {s}\n", .{ spaces, typeStr });
    }

    pub fn deinit(self: Interface) void {
        self.type.deinit();
    }
};

pub fn parseInterfaces(parser: *Parser, tokens: []Token) ParseError![]Interface {
    var interfaces = ArrayList(Interface).init(parser.allocator);

    const implementsToken = parser.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
    const implementsStr = try parser.getTokenValue(implementsToken);
    defer parser.allocator.free(implementsStr);
    if (implementsToken.tag != Token.Tag.identifier or !strEq(implementsStr, "implements")) {
        return interfaces.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
    }

    try parser.consumeSpecificIdentifier(tokens, "implements");

    var nextToken = parser.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;

    while (nextToken.tag == Token.Tag.identifier) {
        const namedType = try parseNamedType(parser, tokens, false);
        const interface = Interface{
            .allocator = parser.allocator,
            .type = namedType,
        };
        interfaces.append(interface) catch return ParseError.UnexpectedMemoryError;

        nextToken = parser.peekNextToken(tokens) orelse break;
        if (nextToken.tag != Token.Tag.punct_ampersand) break;

        _ = try parser.consumeSpecificToken(tokens, Token.Tag.punct_ampersand);
        nextToken = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
    }

    return interfaces.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
}

test "parseInterfaces" {
    var parser = Parser.init(std.testing.allocator);

    const buffer = "implements AA & BB";

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const interfaces = try parseInterfaces(&parser, tokens);
    defer {
        for (interfaces) |interface| {
            interface.deinit();
        }
        testing.allocator.free(interfaces);
    }

    try std.testing.expectEqual(2, interfaces.len);
    try std.testing.expectEqualStrings("AA", interfaces[0].type.namedType.name);
    try std.testing.expectEqualStrings("BB", interfaces[1].type.namedType.name);
}
