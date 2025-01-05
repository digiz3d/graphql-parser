const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const t = @import("../tokenizer.zig");
const Token = t.Token;
const Tokenizer = t.Tokenizer;
const p = @import("../parser.zig");
const Parser = p.Parser;
const ParseError = p.ParseError;

const Field = @import("field.zig").Field;

const NamedType = struct {
    allocator: Allocator,
    name: []const u8,

    pub fn printAST(self: NamedType, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);

        std.debug.print("{s}- NamedType\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
    }

    pub fn deinit(self: NamedType) void {
        self.allocator.free(self.name);
    }
};

const ListType = struct {
    allocator: Allocator,
    elementType: *Type,

    pub fn printAST(self: ListType, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);

        std.debug.print("{s}- ListType\n", .{spaces});
        self.elementType.*.printAST(indent + 1, self.allocator);
    }

    pub fn deinit(self: ListType) void {
        self.elementType.*.deinit();
        self.allocator.destroy(self.elementType);
    }
};

const NonNullType = union(enum) {
    namedType: NamedType,
    listType: ListType,

    pub fn printAST(self: NonNullType, indent: usize, allocator: Allocator) void {
        const spaces = makeIndentation(indent, allocator);
        defer allocator.free(spaces);

        std.debug.print("{s}- NonNull\n", .{spaces});
        switch (self) {
            .namedType => |n| n.printAST(indent + 1),
            .listType => |n| n.printAST(indent + 1),
        }
    }

    pub fn deinit(self: NonNullType) void {
        switch (self) {
            .namedType => |n| n.deinit(),
            .listType => |n| n.deinit(),
        }
    }
};

pub const Type = union(enum) {
    namedType: NamedType,
    listType: ListType,
    nonNullType: NonNullType,

    pub fn printAST(self: Type, indent: usize, allocator: Allocator) void {
        switch (self) {
            .namedType => |n| n.printAST(indent + 1),
            .listType => |n| n.printAST(indent + 1),
            .nonNullType => |n| n.printAST(indent + 1, allocator),
        }
    }

    pub fn deinit(self: Type) void {
        switch (self) {
            .namedType => |n| n.deinit(),
            .listType => |n| n.deinit(),
            .nonNullType => |n| n.deinit(),
        }
    }
};

fn parseNamedType(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError!Type {
    const typeNameToken = parser.consumeNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
    if (typeNameToken.tag != Token.Tag.identifier) return ParseError.ExpectedName;
    const name = try parser.getTokenValue(typeNameToken, allocator);
    var temporaryType = Type{
        .namedType = NamedType{
            .allocator = allocator,
            .name = name,
        },
    };

    const nextToken = parser.peekNextToken(tokens) orelse return temporaryType;
    if (nextToken.tag == Token.Tag.punct_excl) {
        _ = parser.consumeNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
        temporaryType = wrapNonNullType(temporaryType);
    }

    return temporaryType;
}

fn parseListType(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError!Type {
    const bracketLeftToken = parser.consumeNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
    if (bracketLeftToken.tag != Token.Tag.punct_bracket_left) return ParseError.ExpectedBracketLeft;

    const elementType: *Type = allocator.create(Type) catch return ParseError.UnexpectedMemoryError;
    elementType.* = try parseType(parser, tokens, allocator);

    const bracketRightToken = parser.consumeNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
    if (bracketRightToken.tag != Token.Tag.punct_bracket_right) return ParseError.ExpectedBracketRight;

    var temporaryType = Type{
        .listType = ListType{
            .allocator = allocator,
            .elementType = elementType,
        },
    };

    const nextToken = parser.peekNextToken(tokens) orelse return temporaryType;
    if (nextToken.tag == Token.Tag.punct_excl) {
        _ = parser.consumeNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
        temporaryType = wrapNonNullType(temporaryType);
    }

    return temporaryType;
}

fn wrapNonNullType(tempType: Type) Type {
    switch (tempType) {
        .namedType => |n| {
            return Type{ .nonNullType = NonNullType{
                .namedType = n,
            } };
        },
        .listType => |n| {
            return Type{ .nonNullType = NonNullType{
                .listType = n,
            } };
        },
        else => unreachable,
    }
}

pub fn parseType(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError!Type {
    const typeNameOrListToken = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError catch return ParseError.UnexpectedMemoryError;

    if (typeNameOrListToken.tag == Token.Tag.identifier) {
        return parseNamedType(parser, tokens, allocator);
    } else if (typeNameOrListToken.tag == Token.Tag.punct_bracket_left) {
        return parseListType(parser, tokens, allocator);
    }

    return ParseError.ExpectedName;
}

test "parsing simple type" {
    try runTest("String");
}

test "parsing mandatory simple type" {
    try runTest("String!");
}

test "parsing array type" {
    try runTest("[String]");
}

test "parsing mandatory array of simple type" {
    try runTest("[String]!");
}

test "parsing mandatory array of mandatory simple type" {
    try runTest("[String!]!");
}

test "parsing mandatory array of array of mandatory simple type" {
    try runTest("[[String!]]!");
}

fn runTest(buffer: [:0]const u8) !void {
    var parser = Parser.init();

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const ok = try parseType(&parser, tokens, testing.allocator);
    defer ok.deinit();
}
