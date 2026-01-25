const std = @import("std");
const testing = std.testing;
const allocPrint = std.fmt.allocPrint;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("../parser.zig");
const Parser = p.Parser;
const ParseError = p.ParseError;
const strEq = @import("../utils/utils.zig").strEq;
const t = @import("../tokenizer.zig");
const Token = t.Token;
const Tokenizer = t.Tokenizer;

pub const InputValue = union(enum) {
    variable: Variable,
    int_value: IntValue,
    float_value: FloatValue,
    string_value: StringValue,
    boolean_value: BooleanValue,
    null_value: NullValue,
    enum_value: EnumValue,
    list_value: ListValue,
    object_value: ObjectValue,

    pub fn getPrintableString(self: InputValue, allocator: Allocator) []const u8 {
        const typeName = @tagName(self);
        switch (self) {
            InputValue.variable => {
                const variable = self.variable;
                return allocPrint(allocator, "${s} ({s})", .{ variable.name, typeName }) catch return "";
            },
            InputValue.int_value => {
                const int_value = self.int_value;
                return allocPrint(allocator, "{d} ({s})", .{ int_value.value, typeName }) catch return "";
            },
            InputValue.float_value => {
                const float_value = self.float_value;
                return allocPrint(allocator, "{d} ({s})", .{ float_value.value, typeName }) catch return "";
            },
            InputValue.string_value => {
                const string_value = self.string_value;
                return allocPrint(allocator, "{s} ({s})", .{ string_value.value, typeName }) catch return "";
            },
            InputValue.boolean_value => {
                const boolean_value = self.boolean_value;
                return allocPrint(allocator, "{} ({s})", .{ boolean_value.value, typeName }) catch return "";
            },
            InputValue.null_value => {
                return allocPrint(allocator, "null ({s})", .{typeName}) catch return "";
            },
            InputValue.enum_value => {
                const enum_value = self.enum_value;
                return allocPrint(allocator, "{s} ({s})", .{ enum_value.name, typeName }) catch return "";
            },
            InputValue.list_value => {
                const list_value = self.list_value;
                var result = ArrayList(u8).init(allocator);
                defer result.deinit();

                result.appendSlice("[") catch return "";
                for (list_value.values, 0..) |value, i| {
                    if (i > 0) result.appendSlice(", ") catch return "";
                    const printableString = value.getPrintableString(allocator);
                    defer allocator.free(printableString);
                    result.appendSlice(printableString) catch return "";
                }
                result.appendSlice("]") catch return "";

                return result.toOwnedSlice() catch return "";
            },
            InputValue.object_value => {
                const object_value = self.object_value;
                var result = ArrayList(u8).init(allocator);
                defer result.deinit();

                result.appendSlice("{") catch return "";
                for (object_value.fields, 0..) |field, i| {
                    if (i > 0) result.appendSlice(", ") catch return "";
                    result.appendSlice(field.name) catch return "";
                    result.appendSlice(": ") catch return "";
                    const printableString = field.value.getPrintableString(allocator);
                    defer allocator.free(printableString);
                    result.appendSlice(printableString) catch return "";
                }
                result.appendSlice("}") catch return "";

                return result.toOwnedSlice() catch return "";
            },
        }
    }

    pub fn deinit(self: InputValue, allocator: Allocator) void {
        switch (self) {
            .variable => |*x| {
                allocator.free(x.name);
            },
            .int_value => {},
            .float_value => {},
            .string_value => |*x| {
                allocator.free(x.value);
            },
            .boolean_value => {},
            .null_value => {},
            .enum_value => |*x| {
                allocator.free(x.name);
            },
            .list_value => |*x| {
                for (x.values) |value| {
                    value.deinit(allocator);
                }
                allocator.free(x.values);
            },
            .object_value => |*x| {
                for (x.fields) |field| {
                    field.value.deinit(allocator);
                    allocator.free(field.name);
                }
                allocator.free(x.fields);
            },
        }
    }
};

pub const Variable = struct {
    name: []const u8,
};

pub const IntValue = struct {
    value: i32,
};

pub const FloatValue = struct {
    value: f64,
};

pub const StringValue = struct {
    value: []const u8,
    block: bool,
};

pub const BooleanValue = struct {
    value: bool,
};

pub const NullValue = struct {};

pub const EnumValue = struct {
    name: []const u8,
};

pub const ListValue = struct {
    values: []InputValue,
};

pub const ObjectValue = struct {
    fields: []ObjectField,
};

pub const ObjectField = struct {
    name: []const u8,
    value: InputValue,
};

pub fn parseInputValue(parser: *Parser, acceptVariables: bool) ParseError!InputValue {
    var token = parser.peekNextToken() orelse return ParseError.EmptyTokenList;
    if (token.tag == Token.Tag.punct_dollar and !acceptVariables) {
        return ParseError.ExpectedName;
    }

    var str = token.getStringValue(parser.allocator) catch return ParseError.UnexpectedMemoryError;
    defer parser.allocator.free(str);

    switch (token.tag) {
        Token.Tag.punct_brace_left,
        Token.Tag.punct_bracket_left,
        => {},
        else => {
            token = parser.consumeNextToken() orelse return ParseError.EmptyTokenList;
        },
    }

    switch (token.tag) {
        Token.Tag.integer_literal => return InputValue{
            .int_value = IntValue{
                .value = std.fmt.parseInt(i32, str, 10) catch return ParseError.UnexpectedMemoryError,
            },
        },
        Token.Tag.float_literal => return InputValue{
            .float_value = FloatValue{
                .value = std.fmt.parseFloat(f64, str) catch return ParseError.UnexpectedMemoryError,
            },
        },
        Token.Tag.string_literal, Token.Tag.string_literal_block => {
            const strCopy = parser.allocator.dupe(u8, str) catch return ParseError.UnexpectedMemoryError;
            return InputValue{
                .string_value = StringValue{
                    .value = strCopy,
                    .block = token.tag == Token.Tag.string_literal_block,
                },
            };
        },
        Token.Tag.identifier => {
            if (strEq(str, "true")) {
                return InputValue{
                    .boolean_value = BooleanValue{
                        .value = true,
                    },
                };
            } else if (strEq(str, "false")) {
                return InputValue{
                    .boolean_value = BooleanValue{
                        .value = false,
                    },
                };
            } else if (strEq(str, "null")) {
                return InputValue{
                    .null_value = NullValue{},
                };
            } else {
                return InputValue{
                    .enum_value = EnumValue{
                        .name = token.getStringValue(parser.allocator) catch return ParseError.UnexpectedMemoryError,
                    },
                };
            }
        },
        Token.Tag.punct_dollar => {
            token = try parser.consumeToken(Token.Tag.identifier);
            parser.allocator.free(str);
            str = token.getStringValue(parser.allocator) catch return ParseError.UnexpectedMemoryError;

            const strCopy = parser.allocator.dupe(u8, str) catch return ParseError.UnexpectedMemoryError;
            return InputValue{
                .variable = Variable{
                    .name = strCopy,
                },
            };
        },
        Token.Tag.punct_brace_left => {
            return parseObjectValue(parser);
        },
        Token.Tag.punct_bracket_left => {
            return parseListValue(parser);
        },
        else => return ParseError.NotImplemented,
    }
    return ParseError.NotImplemented;
}

fn parseListValue(parser: *Parser) ParseError!InputValue {
    var token = try parser.consumeToken(Token.Tag.punct_bracket_left);

    var values: ArrayList(InputValue) = .empty;

    while (true) {
        token = parser.peekNextToken() orelse return ParseError.EmptyTokenList;
        if (token.tag == Token.Tag.punct_bracket_right) {
            _ = try parser.consumeToken(Token.Tag.punct_bracket_right);
            break;
        }
        const value = try parseInputValue(parser, false);
        values.append(parser.allocator, value) catch return ParseError.UnexpectedMemoryError;
    }

    return InputValue{
        .list_value = ListValue{
            .values = values.toOwnedSlice(parser.allocator) catch return ParseError.UnexpectedMemoryError,
        },
    };
}

fn parseObjectValue(parser: *Parser) ParseError!InputValue {
    var token = try parser.consumeToken(Token.Tag.punct_brace_left);

    var fields: ArrayList(ObjectField) = .empty;

    while (true) {
        token = parser.peekNextToken() orelse return ParseError.ExpectedRightBrace;
        if (token.tag == Token.Tag.punct_brace_right) {
            _ = try parser.consumeToken(Token.Tag.punct_brace_right);
            break;
        }
        const field = try parseObjectField(parser);
        fields.append(parser.allocator, field) catch return ParseError.UnexpectedMemoryError;
    }

    return InputValue{
        .object_value = ObjectValue{
            .fields = fields.toOwnedSlice(parser.allocator) catch return ParseError.UnexpectedMemoryError,
        },
    };
}

fn parseObjectField(parser: *Parser) ParseError!ObjectField {
    var fieldNameToken = try parser.consumeToken(Token.Tag.identifier);
    const fieldName = fieldNameToken.getStringValue(parser.allocator) catch return ParseError.UnexpectedMemoryError;
    _ = try parser.consumeToken(Token.Tag.punct_colon);
    const fieldValue = try parseInputValue(parser, false);
    return ObjectField{
        .name = fieldName,
        .value = fieldValue,
    };
}

test "parsing integer values" {
    var parser = try Parser.initFromBuffer(testing.allocator, "42");
    defer parser.deinit();

    const inputValue = try parseInputValue(&parser, false);
    defer inputValue.deinit(testing.allocator);

    try testing.expectEqual(InputValue{ .int_value = IntValue{ .value = 42 } }, inputValue);
    try testing.expectEqual(@as(i32, 42), inputValue.int_value.value);
}

test "parsing float values" {
    var parser = try Parser.initFromBuffer(testing.allocator, "3.14");
    defer parser.deinit();

    const inputValue = try parseInputValue(&parser, false);
    defer inputValue.deinit(testing.allocator);

    try testing.expectEqual(InputValue{ .float_value = FloatValue{ .value = 3.14 } }, inputValue);
    try testing.expectEqual(@as(f64, 3.14), inputValue.float_value.value);
}

test "parsing string values" {
    var parser = try Parser.initFromBuffer(testing.allocator, "\"hello world\"");
    defer parser.deinit();

    const inputValue = try parseInputValue(&parser, false);
    defer inputValue.deinit(testing.allocator);

    try testing.expectEqualStrings("\"hello world\"", inputValue.string_value.value);
    try testing.expectEqual(false, inputValue.string_value.block);
}

test "parsing block string values" {
    var parser = try Parser.initFromBuffer(testing.allocator, "\"\"\"hello\nworld\"\"\"");
    defer parser.deinit();

    const inputValue = try parseInputValue(&parser, false);
    defer inputValue.deinit(testing.allocator);

    try testing.expectEqualStrings("\"\"\"hello\nworld\"\"\"", inputValue.string_value.value);
    try testing.expectEqual(true, inputValue.string_value.block);
}

test "parsing boolean values" {
    var parser = try Parser.initFromBuffer(testing.allocator, "true");
    defer parser.deinit();

    const inputValue = try parseInputValue(&parser, false);
    defer inputValue.deinit(testing.allocator);

    try testing.expectEqual(InputValue{ .boolean_value = BooleanValue{ .value = true } }, inputValue);
    try testing.expectEqual(true, inputValue.boolean_value.value);
}

test "parsing false boolean values" {
    var parser = try Parser.initFromBuffer(testing.allocator, "false");
    defer parser.deinit();

    const inputValue = try parseInputValue(&parser, false);
    defer inputValue.deinit(testing.allocator);

    try testing.expectEqual(InputValue{ .boolean_value = BooleanValue{ .value = false } }, inputValue);
    try testing.expectEqual(false, inputValue.boolean_value.value);
}

test "parsing null values" {
    var parser = try Parser.initFromBuffer(testing.allocator, "null");
    defer parser.deinit();

    const inputValue = try parseInputValue(&parser, false);
    defer inputValue.deinit(testing.allocator);

    try testing.expectEqual(InputValue{ .null_value = NullValue{} }, inputValue);
}

test "parsing enum values" {
    var parser = try Parser.initFromBuffer(testing.allocator, "ENUM_VALUE");
    defer parser.deinit();

    const inputValue = try parseInputValue(&parser, false);
    defer inputValue.deinit(testing.allocator);

    try testing.expectEqualStrings("ENUM_VALUE", inputValue.enum_value.name);
}

test "parsing variable values with acceptVariables true" {
    var parser = try Parser.initFromBuffer(testing.allocator, "$variableName");
    defer parser.deinit();

    const inputValue = try parseInputValue(&parser, true);
    defer inputValue.deinit(testing.allocator);

    try testing.expectEqualStrings("variableName", inputValue.variable.name);
}

test "parsing variable values with acceptVariables false should fail" {
    var parser = try Parser.initFromBuffer(testing.allocator, "$variableName");
    defer parser.deinit();

    const result = parseInputValue(&parser, false);
    try testing.expectError(ParseError.ExpectedName, result);
}

test "parsing list values" {
    var parser = try Parser.initFromBuffer(testing.allocator, "[1, 2, 3]");
    defer parser.deinit();

    const inputValue = try parseInputValue(&parser, false);
    defer inputValue.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 3), inputValue.list_value.values.len);
    try testing.expectEqual(@as(i32, 1), inputValue.list_value.values[0].int_value.value);
    try testing.expectEqual(@as(i32, 2), inputValue.list_value.values[1].int_value.value);
    try testing.expectEqual(@as(i32, 3), inputValue.list_value.values[2].int_value.value);
}

test "parsing empty list values" {
    var parser = try Parser.initFromBuffer(testing.allocator, "[]");
    defer parser.deinit();

    const inputValue = try parseInputValue(&parser, false);
    defer inputValue.deinit(testing.allocator);

    try testing.expectEqual(InputValue{ .list_value = ListValue{ .values = &[_]InputValue{} } }, inputValue);
    try testing.expectEqual(@as(usize, 0), inputValue.list_value.values.len);
}

test "parsing object values" {
    var parser = try Parser.initFromBuffer(testing.allocator, "{name: \"John\", age: 30}");
    defer parser.deinit();

    const inputValue = try parseInputValue(&parser, false);
    defer inputValue.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 2), inputValue.object_value.fields.len);
    try testing.expectEqualStrings("name", inputValue.object_value.fields[0].name);
    try testing.expectEqualStrings("\"John\"", inputValue.object_value.fields[0].value.string_value.value);
    try testing.expectEqualStrings("age", inputValue.object_value.fields[1].name);
    try testing.expectEqual(@as(i32, 30), inputValue.object_value.fields[1].value.int_value.value);
}

test "parsing empty object values" {
    var parser = try Parser.initFromBuffer(testing.allocator, "{}");
    defer parser.deinit();

    const inputValue = try parseInputValue(&parser, false);
    defer inputValue.deinit(testing.allocator);

    try testing.expectEqual(InputValue{ .object_value = ObjectValue{ .fields = &[_]ObjectField{} } }, inputValue);
    try testing.expectEqual(@as(usize, 0), inputValue.object_value.fields.len);
}

test "parsing nested complex values" {
    var parser = try Parser.initFromBuffer(testing.allocator, "{items: [1, 2, {nested: true}], count: 3}");
    defer parser.deinit();

    const inputValue = try parseInputValue(&parser, false);
    defer inputValue.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 2), inputValue.object_value.fields.len);

    const itemsField = inputValue.object_value.fields[0];
    try testing.expectEqualStrings("items", itemsField.name);
    try testing.expectEqual(@as(usize, 3), itemsField.value.list_value.values.len);

    const nestedObject = itemsField.value.list_value.values[2];
    try testing.expectEqualStrings("nested", nestedObject.object_value.fields[0].name);
    try testing.expectEqual(true, nestedObject.object_value.fields[0].value.boolean_value.value);
}
