const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const p = @import("../parser.zig");
const Parser = p.Parser;
const ParseError = p.ParseError;

const Directive = @import("directive.zig").Directive;
const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const OperationTypeDefinition = @import("operation_type_definition.zig").OperationTypeDefinition;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseOperationTypeDefinitions = @import("operation_type_definition.zig").parseOperationTypeDefinitions;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;

pub const SchemaExtension = struct {
    allocator: Allocator,
    directives: []Directive,
    operationTypes: []OperationTypeDefinition,

    pub fn deinit(self: SchemaExtension) void {
        for (self.directives) |directive| {
            directive.deinit();
        }
        self.allocator.free(self.directives);
        for (self.operationTypes) |operationType| {
            operationType.deinit();
        }
        self.allocator.free(self.operationTypes);
    }

    pub fn printAST(self: SchemaExtension, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- SchemaExtension\n", .{spaces});
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |directive| {
            directive.printAST(indent + 1);
        }
        std.debug.print("{s}  operationTypes: {d}\n", .{ spaces, self.operationTypes.len });
        for (self.operationTypes) |operationType| {
            operationType.printAST(indent + 1);
        }
    }
};

pub fn parseSchemaExtension(parser: *Parser, tokens: []Token) ParseError!SchemaExtension {
    try parser.consumeSpecificIdentifier(tokens, "extend");
    try parser.consumeSpecificIdentifier(tokens, "schema");

    const directives = try parseDirectives(parser, tokens);
    const operationTypes = try parseOperationTypeDefinitions(parser, tokens);
    return SchemaExtension{
        .allocator = parser.allocator,
        .directives = directives,
        .operationTypes = operationTypes,
    };
}

test "parsing schema extension" {
    var parser = Parser.init(testing.allocator);
    const buffer =
        \\ extend schema @someDirective {
        \\   mutation: Mutation
        \\   subscription: Subscription
        \\ }
        \\
    ;

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const schema = try parseSchemaExtension(&parser, tokens);
    defer schema.deinit();

    try testing.expectEqual(2, schema.operationTypes.len);
    try testing.expectEqual(1, schema.directives.len);
}
