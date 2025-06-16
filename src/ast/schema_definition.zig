const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;

const Directive = @import("directive.zig").Directive;
const SelectionSet = @import("selection_set.zig").SelectionSet;
const OperationTypeDefinition = @import("operation_type_definition.zig").OperationTypeDefinition;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const ParseError = @import("../parser.zig").ParseError;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseOperationTypeDefinitions = @import("operation_type_definition.zig").parseOperationTypeDefinitions;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;

pub const SchemaDefinition = struct {
    allocator: Allocator,
    description: ?[]const u8,
    directives: []Directive,
    operationTypes: []OperationTypeDefinition,

    pub fn printAST(self: SchemaDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- SchemaDefinition\n", .{spaces});
        if (self.description != null) {
            const newDescription = newLineToBackslashN(self.allocator, self.description.?);
            defer self.allocator.free(newDescription);
            std.debug.print("{s}  description = \"{s}\"\n", .{ spaces, newDescription });
        } else {
            std.debug.print("{s}  description = null\n", .{spaces});
        }
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
        if (self.description != null) {
            self.allocator.free(self.description.?);
        }
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

pub fn parseSchemaDefinition(parser: *Parser, tokens: []Token) ParseError!SchemaDefinition {
    const description = try parseOptionalDescription(parser, tokens);

    _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;

    const directivesNodes = try parseDirectives(parser, tokens);

    const operationTypes = try parseOperationTypeDefinitions(parser, tokens);

    return SchemaDefinition{
        .allocator = parser.allocator,
        .description = description,
        .directives = directivesNodes,
        .operationTypes = operationTypes,
    };
}

test "parsing schema" {
    var parser = Parser.init(testing.allocator);
    const buffer =
        \\ schema {
        \\   query: Query
        \\   mutation: Mutation
        \\ }
    ;

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const schema = try parseSchemaDefinition(&parser, tokens);
    defer schema.deinit();

    try testing.expectEqual(2, schema.operationTypes.len);
    try testing.expectEqual(null, schema.description);
}
