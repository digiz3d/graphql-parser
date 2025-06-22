const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

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

pub fn parseOperationTypeDefinitions(parser: *Parser, tokens: []Token) ParseError![]OperationTypeDefinition {
    var definitions = ArrayList(OperationTypeDefinition).init(parser.allocator);

    _ = try parser.consumeToken(tokens, Token.Tag.punct_brace_left);

    while (true) {
        const opTypeToken = parser.consumeToken(tokens, Token.Tag.identifier) catch return ParseError.ExpectedName;
        const operationType = try parser.getTokenValue(opTypeToken);
        defer parser.allocator.free(operationType);

        if (!strEq(operationType, "query") and !strEq(operationType, "mutation") and !strEq(operationType, "subscription")) {
            return ParseError.InvalidOperationType;
        }

        _ = try parser.consumeToken(tokens, Token.Tag.punct_colon);
        const typeNameToken = try parser.consumeToken(tokens, Token.Tag.identifier);
        const typeName = try parser.getTokenValue(typeNameToken);
        defer parser.allocator.free(typeName);

        const definition = parseOperationTypeDefinition(parser.allocator, operationType, typeName) catch return ParseError.UnexpectedMemoryError;
        definitions.append(definition) catch return ParseError.UnexpectedMemoryError;

        const nextToken = parser.peekNextToken(tokens) orelse break;
        if (nextToken.tag == Token.Tag.punct_brace_right) {
            _ = try parser.consumeToken(tokens, Token.Tag.punct_brace_right);
            break;
        }
    }

    return definitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
}

test "parsing operation types definitions" {
    const buffer =
        \\ {
        \\   query: Query
        \\   mutation: Mutation
        \\ }
    ;

    const operationTypes = try runTest(buffer);
    defer {
        for (operationTypes) |operationType| {
            operationType.deinit();
        }
        testing.allocator.free(operationTypes);
    }
}

test "wrong operation type" {
    const buffer =
        \\ {
        \\   queryxxx: Query
        \\ }
    ;

    const operationTypes = runTest(buffer);
    try testing.expectError(ParseError.InvalidOperationType, operationTypes);
}

fn runTest(buffer: [:0]const u8) ![]OperationTypeDefinition {
    var parser = Parser.init(testing.allocator);

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    return parseOperationTypeDefinitions(&parser, tokens);
}
