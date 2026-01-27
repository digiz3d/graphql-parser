const std = @import("std");
const testing = std.testing;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const tok = @import("tokenizer.zig");
const Token = tok.Token;
const Tokenizer = tok.Tokenizer;
const printTokens = tok.printTokens;

const input = @import("ast/input_value.zig");
const parseDirectives = @import("ast/directive.zig").parseDirectives;
const parseSelectionSet = @import("ast/selection_set.zig").parseSelectionSet;
const parseVariableDefinition = @import("ast/variable_definition.zig").parseVariableDefinition;
const parseOperationTypeDefinitions = @import("ast/operation_type_definition.zig").parseOperationTypeDefinitions;
const parseObjectTypeDefinition = @import("ast/object_type_definition.zig").parseObjectTypeDefinition;
const parseUnionTypeDefinition = @import("ast/union_type_definition.zig").parseUnionTypeDefinition;
const parseScalarTypeDefinition = @import("ast/scalar_type_definition.zig").parseScalarTypeDefinition;
const parseSchemaDefinition = @import("ast/schema_definition.zig").parseSchemaDefinition;
const parseFragmentDefinition = @import("ast/fragment_definition.zig").parseFragmentDefinition;
const parseOperationDefinition = @import("ast/operation_definition.zig").parseOperationDefinition;
const parseDirectiveDefinition = @import("ast/directive_definition.zig").parseDirectiveDefinition;
const parseInterfaceTypeDefinition = @import("ast/interface_type_definition.zig").parseInterfaceTypeDefinition;
const parseSchemaExtension = @import("ast/schema_extension.zig").parseSchemaExtension;
const parseObjectTypeExtension = @import("ast/object_type_extension.zig").parseObjectTypeExtension;
const parseEnumTypeDefinition = @import("ast/enum_type_definition.zig").parseEnumTypeDefinition;
const parseEnumTypeExtension = @import("ast/enum_type_extension.zig").parseEnumTypeExtension;
const parseInputObjectTypeDefinition = @import("ast/input_object_type_definition.zig").parseInputObjectTypeDefinition;
const parseInputObjectTypeExtension = @import("ast/input_object_type_extension.zig").parseInputObjectTypeExtension;
const parseInterfaceTypeExtension = @import("ast/interface_type_extension.zig").parseInterfaceTypeExtension;
const parseUnionTypeExtension = @import("ast/union_type_extension.zig").parseUnionTypeExtension;
const parseScalarTypeExtension = @import("ast/scalar_type_extension.zig").parseScalarTypeExtension;

const Document = @import("ast/document.zig").Document;
const ExecutableDefinition = @import("ast/executable_definition.zig").ExecutableDefinition;
const FragmentDefinition = @import("ast/fragment_definition.zig").FragmentDefinition;
const SchemaDefinition = @import("ast/schema_definition.zig").SchemaDefinition;
const op = @import("ast/operation_definition.zig");
const OperationType = op.OperationType;
const OperationDefinition = op.OperationDefinition;

const strEq = @import("utils/utils.zig").strEq;

pub const ParseError = error{
    EmptyTokenList,
    ExpectedAt,
    ExpectedColon,
    ExpectedDollar,
    ExpectedName,
    ExpectedNameNotOn,
    ExpectedOn,
    ExpectedRightBrace,
    InvalidLocation,
    InvalidOperationType,
    MissingExpectedBrace,
    NotImplemented,
    UnexpectedExclamationMark,
    UnexpectedMemoryError,
    UnexpectedToken,
};

pub const Parser = struct {
    allocator: Allocator,
    index: usize = 0,
    tokens: []Token,

    const Reading = enum {
        root,
        fragment_definition,
        operation_definition,
        schema_definition,
        object_type_definition,
        union_type_definition,
        scalar_type_definition,
        directive_definition,
        interface_type_definition,
        schema_extension,
        object_type_extension,
        enum_type_definition,
        enum_type_extension,
        input_object_type_definition,
        input_object_type_extension,
        interface_type_extension,
        union_type_extension,
        scalar_type_extension,
    };

    pub fn initFromBuffer(allocator: Allocator, buffer: [:0]const u8) ParseError!Parser {
        var tokenizer = Tokenizer.init(allocator, buffer);
        defer tokenizer.deinit();
        const tokens = tokenizer.getAllTokens() catch return ParseError.UnexpectedMemoryError;
        return Parser{ .allocator = allocator, .tokens = tokens };
    }

    pub fn deinit(self: *Parser) void {
        self.allocator.free(self.tokens);
    }

    pub fn parse(self: *Parser) ParseError!Document {
        const document = try self.processTokens();
        return document;
    }

    fn processTokens(self: *Parser) ParseError!Document {
        var docDefinitions: ArrayList(ExecutableDefinition) = .empty;

        state: switch (Reading.root) {
            Reading.root => {
                var token = self.peekNextToken() orelse break :state;

                if (token.tag == Token.Tag.eof) {
                    break :state;
                }

                const isDescription = token.tag == Token.Tag.string_literal or token.tag == Token.Tag.string_literal_block;
                if (isDescription) {
                    token = self.peekNextNextToken() orelse return ParseError.EmptyTokenList;
                }
                if (token.tag != Token.Tag.identifier) {
                    std.debug.print("expected name {}\n", .{token.tag});
                    return ParseError.ExpectedName;
                }

                const str = token.getStringRef();
                if (strEq(str, "query") or strEq(str, "mutation") or strEq(str, "subscription")) {
                    continue :state Reading.operation_definition;
                } else if (strEq(str, "fragment")) {
                    continue :state Reading.fragment_definition;
                } else if (strEq(str, "schema")) {
                    continue :state Reading.schema_definition;
                } else if (strEq(str, "type")) {
                    continue :state Reading.object_type_definition;
                } else if (strEq(str, "input")) {
                    continue :state Reading.input_object_type_definition;
                } else if (strEq(str, "union")) {
                    continue :state Reading.union_type_definition;
                } else if (strEq(str, "scalar")) {
                    continue :state Reading.scalar_type_definition;
                } else if (strEq(str, "directive")) {
                    continue :state Reading.directive_definition;
                } else if (strEq(str, "enum")) {
                    continue :state Reading.enum_type_definition;
                } else if (strEq(str, "interface")) {
                    continue :state Reading.interface_type_definition;
                } else if (strEq(str, "extend")) {
                    const nextToken = self.peekNextNextToken() orelse return ParseError.EmptyTokenList;
                    const nextTokenStr = nextToken.getStringRef();

                    if (strEq(nextTokenStr, "schema")) {
                        continue :state Reading.schema_extension;
                    } else if (strEq(nextTokenStr, "type")) {
                        continue :state Reading.object_type_extension;
                    } else if (strEq(nextTokenStr, "enum")) {
                        continue :state Reading.enum_type_extension;
                    } else if (strEq(nextTokenStr, "input")) {
                        continue :state Reading.input_object_type_extension;
                    } else if (strEq(nextTokenStr, "interface")) {
                        continue :state Reading.interface_type_extension;
                    } else if (strEq(nextTokenStr, "union")) {
                        continue :state Reading.union_type_extension;
                    } else if (strEq(nextTokenStr, "scalar")) {
                        continue :state Reading.scalar_type_extension;
                    } else {
                        return ParseError.NotImplemented;
                    }
                }
                return ParseError.InvalidOperationType;
            },
            Reading.fragment_definition => {
                const fragmentDefinition = try parseFragmentDefinition(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .fragmentDefinition = fragmentDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.operation_definition => {
                const operationDefinition = try parseOperationDefinition(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .operationDefinition = operationDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.schema_definition => {
                const schemaDefinition = try parseSchemaDefinition(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .schemaDefinition = schemaDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.object_type_definition => {
                const objectTypeDefinition = try parseObjectTypeDefinition(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .objectTypeDefinition = objectTypeDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.union_type_definition => {
                const unionTypeDefinition = try parseUnionTypeDefinition(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .unionTypeDefinition = unionTypeDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.scalar_type_definition => {
                const scalarTypeDefinition = try parseScalarTypeDefinition(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .scalarTypeDefinition = scalarTypeDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.directive_definition => {
                const directiveDefinition = try parseDirectiveDefinition(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .directiveDefinition = directiveDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.interface_type_definition => {
                const interfaceTypeDefinition = try parseInterfaceTypeDefinition(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .interfaceTypeDefinition = interfaceTypeDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.schema_extension => {
                const schemaExtension = try parseSchemaExtension(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .schemaExtension = schemaExtension,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.object_type_extension => {
                const objectTypeExtension = try parseObjectTypeExtension(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .objectTypeExtension = objectTypeExtension,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.enum_type_definition => {
                const enumTypeDefinition = try parseEnumTypeDefinition(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .enumTypeDefinition = enumTypeDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.enum_type_extension => {
                const enumTypeExtension = try parseEnumTypeExtension(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .enumTypeExtension = enumTypeExtension,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.input_object_type_definition => {
                const inputObjectTypeDefinition = try parseInputObjectTypeDefinition(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .inputObjectTypeDefinition = inputObjectTypeDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.input_object_type_extension => {
                const inputObjectTypeExtension = try parseInputObjectTypeExtension(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .inputObjectTypeExtension = inputObjectTypeExtension,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.interface_type_extension => {
                const interfaceTypeExtension = try parseInterfaceTypeExtension(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .interfaceTypeExtension = interfaceTypeExtension,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.union_type_extension => {
                const unionTypeExtension = try parseUnionTypeExtension(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .unionTypeExtension = unionTypeExtension,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.scalar_type_extension => {
                const scalarTypeExtension = try parseScalarTypeExtension(self);
                docDefinitions.append(self.allocator, ExecutableDefinition{
                    .scalarTypeExtension = scalarTypeExtension,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
        }
        return Document{
            .allocator = self.allocator,
            .definitions = docDefinitions.toOwnedSlice(self.allocator) catch return ParseError.UnexpectedMemoryError,
        };
    }

    pub fn peekNextToken(self: *Parser) ?Token {
        if (self.index >= self.tokens.len) {
            return null;
        }
        return self.tokens[self.index];
    }

    pub fn peekNextNextToken(self: *Parser) ?Token {
        if (self.index + 1 >= self.tokens.len) {
            return null;
        }
        return self.tokens[self.index + 1];
    }

    pub fn consumeNextToken(self: *Parser) ?Token {
        if (self.index >= self.tokens.len) {
            return null;
        }
        const nextToken = self.tokens[self.index];
        self.index += 1;
        return nextToken;
    }

    pub fn consumeToken(self: *Parser, tag: Token.Tag) ParseError!Token {
        const nextToken = self.consumeNextToken() orelse return ParseError.EmptyTokenList;
        if (nextToken.tag != tag) {
            return ParseError.UnexpectedToken;
        }
        return nextToken;
    }

    pub fn consumeSpecificIdentifier(self: *Parser, comptime tokenStr: []const u8) ParseError!void {
        const nextToken = try self.consumeToken(Token.Tag.identifier);
        const strValue = nextToken.getStringRef();
        if (!strEq(strValue, tokenStr)) {
            return ParseError.UnexpectedToken;
        }
        return;
    }

    pub fn getTokenValue(self: *Parser, token: Token) ParseError![]const u8 {
        return token.getStringValue(self.allocator) catch return ParseError.UnexpectedMemoryError;
    }

    pub fn getTokenValueRef(_: *Parser, token: Token) []const u8 {
        return token.getStringRef();
    }
};

// error cases
test "initialize invalid document " {
    const buffer = "test { hello }";
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();
    const rootNode = parser.parse();
    try testing.expectError(ParseError.InvalidOperationType, rootNode);
}
