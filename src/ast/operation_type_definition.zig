const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

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

pub fn parseOperationTypeDefinitions(parser: *Parser) ParseError![]OperationTypeDefinition {
    var definitions: ArrayList(OperationTypeDefinition) = .empty;

    _ = try parser.consumeToken(Token.Tag.punct_brace_left);

    while (true) {
        const opTypeToken = parser.consumeToken(Token.Tag.identifier) catch return ParseError.ExpectedName;
        const operationType = parser.getTokenValueRef(opTypeToken);

        if (!strEq(operationType, "query") and !strEq(operationType, "mutation") and !strEq(operationType, "subscription")) {
            return ParseError.InvalidOperationType;
        }

        _ = try parser.consumeToken(Token.Tag.punct_colon);
        const typeNameToken = try parser.consumeToken(Token.Tag.identifier);
        const typeName = parser.getTokenValueRef(typeNameToken);

        const definition = parseOperationTypeDefinition(parser.allocator, operationType, typeName) catch return ParseError.UnexpectedMemoryError;
        definitions.append(parser.allocator, definition) catch return ParseError.UnexpectedMemoryError;

        const nextToken = parser.peekNextToken() orelse break;
        if (nextToken.tag == Token.Tag.punct_brace_right) {
            _ = try parser.consumeToken(Token.Tag.punct_brace_right);
            break;
        }
    }

    return definitions.toOwnedSlice(parser.allocator) catch return ParseError.UnexpectedMemoryError;
}

test "parsing operation types definitions" {
    const buffer =
        \\ {
        \\   query: Query
        \\   mutation: Mutation
        \\ }
    ;
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const operationTypes = try parseOperationTypeDefinitions(&parser);
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
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const operationTypes = parseOperationTypeDefinitions(&parser);
    try testing.expectError(ParseError.InvalidOperationType, operationTypes);
}
