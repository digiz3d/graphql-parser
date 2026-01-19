const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const t = @import("../tokenizer.zig");
const Token = t.Token;
const Tokenizer = t.Tokenizer;
const p = @import("../parser.zig");
const Parser = p.Parser;
const ParseError = p.ParseError;
const Argument = @import("arguments.zig").Argument;
const parseArguments = @import("arguments.zig").parseArguments;

pub const Directive = struct {
    allocator: Allocator,
    arguments: []Argument,
    name: []const u8,

    pub fn deinit(self: Directive) void {
        self.allocator.free(self.name);
        for (self.arguments) |item| {
            item.deinit();
        }
        self.allocator.free(self.arguments);
    }
};

pub fn parseDirectives(parser: *Parser) ParseError![]Directive {
    var directives = ArrayList(Directive).init(parser.allocator);
    var currentToken = parser.peekNextToken() orelse return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
    while (currentToken.tag == Token.Tag.punct_at) : (currentToken = parser.peekNextToken() orelse return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError) {
        _ = try parser.consumeToken(Token.Tag.punct_at);

        const directiveNameToken = parser.consumeToken(Token.Tag.identifier) catch return ParseError.ExpectedName;
        const directiveName = try parser.getTokenValue(directiveNameToken);
        const arguments = try parseArguments(parser);
        const directiveNode = Directive{
            .allocator = parser.allocator,
            .arguments = arguments,
            .name = directiveName,
        };
        directives.append(directiveNode) catch return ParseError.UnexpectedMemoryError;
    }
    return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
}

test "parsing directives" {
    const buffer = "@oneDirective @twoDirective(id: 1, other: $val)";
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const directives = try parseDirectives(&parser);
    defer {
        for (directives) |directive| {
            directive.deinit();
        }
        testing.allocator.free(directives);
    }

    try testing.expectEqual(2, directives.len);
}
