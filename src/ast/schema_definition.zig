const std = @import("std");
const Allocator = std.mem.Allocator;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

const Directive = @import("directive.zig").Directive;
const SelectionSet = @import("selection_set.zig").SelectionSet;
const OperationTypeDefinition = @import("operation_type_definition.zig").OperationTypeDefinition;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const ParseError = @import("../parser.zig").ParseError;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseOperationTypeDefinitions = @import("operation_type_definition.zig").parseOperationTypeDefinitions;

pub const SchemaDefinition = struct {
    allocator: Allocator,
    directives: []Directive,
    operationTypes: []OperationTypeDefinition,

    pub fn printAST(self: SchemaDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- SchemaDefinition\n", .{spaces});
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  operationTypes: {d}\n", .{ spaces, self.operationTypes.len });
        for (self.operationTypes) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: SchemaDefinition) void {
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        for (self.operationTypes) |item| {
            item.deinit();
        }
        self.allocator.free(self.operationTypes);
    }
};

pub fn parseSchemaDefinition(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError!SchemaDefinition {
    _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;

    const directivesNodes = try parseDirectives(parser, tokens, allocator);

    const operationTypes = try parseOperationTypeDefinitions(parser, tokens, allocator);

    return SchemaDefinition{
        .allocator = allocator,
        .directives = directivesNodes,
        .operationTypes = operationTypes,
    };
}
