const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;

const Directive = @import("directive.zig").Directive;
const SelectionSet = @import("selection_set.zig").SelectionSet;
const OperationTypeDefinition = @import("operation_type_definition.zig").OperationTypeDefinition;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const Parser = @import("../parse.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const ParseError = @import("../parse.zig").ParseError;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseOperationTypeDefinitions = @import("operation_type_definition.zig").parseOperationTypeDefinitions;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;
const SchemaExtension = @import("schema_extension.zig").SchemaExtension;

pub const SchemaDefinition = struct {
    allocator: Allocator,
    description: ?[]const u8,
    directives: []Directive,
    operationTypes: []OperationTypeDefinition,

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

    pub fn fromExtension(ext: SchemaExtension) SchemaDefinition {
        return SchemaDefinition{
            .allocator = ext.allocator,
            .description = null,
            .directives = ext.directives,
            .operationTypes = ext.operationTypes,
        };
    }
};

pub fn parseSchemaDefinition(parser: *Parser) ParseError!SchemaDefinition {
    const description = try parseOptionalDescription(parser);

    try parser.consumeSpecificIdentifier("schema");

    const directivesNodes = try parseDirectives(parser);

    const operationTypes = try parseOperationTypeDefinitions(parser);

    return SchemaDefinition{
        .allocator = parser.allocator,
        .description = description,
        .directives = directivesNodes,
        .operationTypes = operationTypes,
    };
}

test "initialize schema without anything" {
    const buffer = "schema {}";
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const schema = parseSchemaDefinition(&parser);

    try testing.expectError(ParseError.ExpectedName, schema);
}

test "parsing schema" {
    const buffer =
        \\ schema {
        \\   query: Query
        \\   mutation: Mutation
        \\ }
    ;
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const schema = try parseSchemaDefinition(&parser);
    defer schema.deinit();

    try testing.expectEqual(2, schema.operationTypes.len);
    try testing.expectEqual(null, schema.description);
}
