const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const p = @import("../parse.zig");
const Parser = p.Parser;
const ParseError = p.ParseError;

const Directive = @import("directive.zig").Directive;
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
};

pub fn parseSchemaExtension(parser: *Parser) ParseError!SchemaExtension {
    try parser.consumeSpecificIdentifier("extend");
    try parser.consumeSpecificIdentifier("schema");

    const directives = try parseDirectives(parser);
    const operationTypes = try parseOperationTypeDefinitions(parser);
    return SchemaExtension{
        .allocator = parser.allocator,
        .directives = directives,
        .operationTypes = operationTypes,
    };
}

test "parsing schema extension" {
    const buffer =
        \\ extend schema @someDirective {
        \\   mutation: Mutation
        \\   subscription: Subscription
        \\ }
    ;
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const schema = try parseSchemaExtension(&parser);
    defer schema.deinit();

    try testing.expectEqual(2, schema.operationTypes.len);
    try testing.expectEqual(1, schema.directives.len);
}
