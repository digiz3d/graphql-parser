const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const parserImport = @import("../parser.zig");
const Parser = parserImport.Parser;
const ParseError = parserImport.ParseError;
const parseDirectives = @import("directive.zig").parseDirectives;
const Directive = @import("directive.zig").Directive;
const FieldDefinition = @import("field_definition.zig").FieldDefinition;
const parseFieldDefinition = @import("field_definition.zig").parseFieldDefinition;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;

pub const ObjectTypeDefinition = struct {
    allocator: Allocator,
    description: ?[]const u8,
    name: []const u8,
    // description: ?[]const u8, // TODO: implement description
    // interfaces: []InterfaceType, // TODO: implement interfaces
    directives: []Directive,
    fields: []FieldDefinition,

    pub fn printAST(self: ObjectTypeDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- ObjectTypeDefinition\n", .{spaces});
        if (self.description != null) {
            const str = newLineToBackslashN(self.allocator, self.description.?);
            defer self.allocator.free(str);
            std.debug.print("{s}  description: {s}\n", .{ spaces, str });
        } else {
            std.debug.print("{s}  description: null\n", .{spaces});
        }
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  fields: {d}\n", .{ spaces, self.fields.len });
        for (self.fields) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: ObjectTypeDefinition) void {
        if (self.description != null) {
            self.allocator.free(self.description.?);
        }
        self.allocator.free(self.name);
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        for (self.fields) |item| {
            item.deinit();
        }
        self.allocator.free(self.fields);
    }
};

pub fn parseObjectTypeDefinition(parser: *Parser, tokens: []Token) ParseError!ObjectTypeDefinition {
    const description = try parseOptionalDescription(parser, tokens);
    _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;

    const nameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    const name = try parser.getTokenValue(nameToken);
    defer parser.allocator.free(name);

    if (nameToken.tag != Token.Tag.identifier) {
        return ParseError.ExpectedName;
    }

    const directives = try parseDirectives(parser, tokens);

    const leftBraceToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (leftBraceToken.tag != Token.Tag.punct_brace_left) {
        return ParseError.ExpectedBracketLeft;
    }

    var nextToken = parser.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;

    var fields = ArrayList(FieldDefinition).init(parser.allocator);
    while (nextToken.tag != Token.Tag.punct_brace_right) {
        const fieldDefinition = try parseFieldDefinition(parser, tokens);
        fields.append(fieldDefinition) catch return ParseError.UnexpectedMemoryError;
        nextToken = parser.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
    }
    _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;

    const objectTypeDefinition = ObjectTypeDefinition{
        .allocator = parser.allocator,
        .description = description,
        .directives = directives,
        .name = parser.allocator.dupe(u8, name) catch return ParseError.UnexpectedMemoryError,
        .fields = fields.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
    };
    return objectTypeDefinition;
}

test "parseObjectTypeDefinition" {
    try runTest(
        \\type Query @lol {
        \\ ok(id:String): Boolean! @lol
        \\}
    , .{ .len = 1 });
}
test "parseObjectTypeDefinition with two fields" {
    try runTest(
        \\type Query {
        \\ ok: Boolean!
        \\ ok2: Boolean
        \\}
    , .{ .len = 2 });
}

fn runTest(buffer: [:0]const u8, expectedLenOrError: union(enum) {
    len: usize,
    parseError: ParseError,
}) !void {
    var parser = Parser.init(testing.allocator);

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    switch (expectedLenOrError) {
        .parseError => |expectedError| {
            const objectTypeDefinition = parseObjectTypeDefinition(&parser, tokens);
            try testing.expectError(expectedError, objectTypeDefinition);
        },
        .len => |length| {
            const objectTypeDefinition = try parseObjectTypeDefinition(&parser, tokens);
            defer objectTypeDefinition.deinit();

            try testing.expectEqual(length, objectTypeDefinition.fields.len);
        },
    }
}
