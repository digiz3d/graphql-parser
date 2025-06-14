const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

const strEq = @import("../utils/utils.zig").strEq;
const t = @import("../tokenizer.zig");
const Token = t.Token;
const Tokenizer = t.Tokenizer;
const Directive = @import("directive.zig").Directive;
const SelectionSet = @import("selection_set.zig").SelectionSet;
const p = @import("../parser.zig");
const Parser = p.Parser;
const ParseError = p.ParseError;

pub const OperationTypeDefinition = struct {
    allocator: Allocator,
    operation: []const u8,
    name: []const u8,

    pub fn printAST(self: OperationTypeDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- OperationTypeDefinition\n", .{spaces});
        std.debug.print("{s}  operation: {s}\n", .{ spaces, self.operation });
        std.debug.print("{s}  name: {s}\n", .{ spaces, self.name });
    }

    pub fn deinit(self: OperationTypeDefinition) void {
        self.allocator.free(self.operation);
        self.allocator.free(self.name);
    }
};

fn parseOperationTypeDefinition(
    allocator: Allocator,
    operation: []const u8,
    name: []const u8,
) !OperationTypeDefinition {
    const operationTypeDef = OperationTypeDefinition{
        .allocator = allocator,
        .operation = try allocator.dupe(u8, operation),
        .name = try allocator.dupe(u8, name),
    };
    return operationTypeDef;
}

pub fn parseOperationTypeDefinitions(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError![]OperationTypeDefinition {
    var definitions = std.ArrayList(OperationTypeDefinition).init(allocator);

    const leftBrace = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedBracketLeft;
    if (leftBrace.tag != Token.Tag.punct_brace_left) {
        return ParseError.ExpectedBracketLeft;
    }

    while (true) {
        const opTypeToken = parser.consumeNextToken(tokens) orelse break;
        if (opTypeToken.tag != Token.Tag.identifier) {
            return ParseError.ExpectedName;
        }
        const operationType = try parser.getTokenValue(opTypeToken, allocator);
        defer allocator.free(operationType);

        if (!strEq(operationType, "query") and !strEq(operationType, "mutation") and !strEq(operationType, "subscription")) {
            return ParseError.InvalidOperationType;
        }

        const colonToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
        if (colonToken.tag != Token.Tag.punct_colon) {
            return ParseError.ExpectedColon;
        }

        const typeNameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
        if (typeNameToken.tag != Token.Tag.identifier) {
            return ParseError.ExpectedName;
        }

        const typeName = try parser.getTokenValue(typeNameToken, allocator);
        defer allocator.free(typeName);

        const definition = parseOperationTypeDefinition(allocator, operationType, typeName) catch return ParseError.UnexpectedMemoryError;
        definitions.append(definition) catch return ParseError.UnexpectedMemoryError;

        // Peek next token: if it's '}', break; else, expect another operation type
        const nextToken = parser.peekNextToken(tokens) orelse break;
        if (nextToken.tag == Token.Tag.punct_brace_right) {
            _ = parser.consumeNextToken(tokens); // consume '}'
            break;
        }
    }

    return definitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
}

test "parsing operation types definitions" {
    var parser = Parser.init();
    const buffer =
        \\ {
        \\   query: Query
        \\   mutation: Mutation
        \\ }
    ;

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const operationTypes = try parseOperationTypeDefinitions(&parser, tokens, testing.allocator);
    defer {
        for (operationTypes) |operationType| {
            operationType.deinit();
        }
        testing.allocator.free(operationTypes);
    }

    try testing.expectEqual(2, operationTypes.len);
}
