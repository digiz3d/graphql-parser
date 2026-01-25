const testing = @import("std").testing;
const Parser = @import("parser.zig").Parser;
const OperationType = @import("ast/operation_definition.zig").OperationType;
const getFileContent = @import("utils/utils.zig").getFileContent;
const normalizeLineEndings = @import("utils/utils.zig").normalizeLineEndings;
const trimTrailingNewlines = @import("utils/utils.zig").trimTrailingNewlines;
const Printer = @import("printer.zig").Printer;
const std = @import("std");

test "e2e-parse" {
    const content = try getFileContent("tests/parser.e2e.graphql", testing.allocator);
    defer testing.allocator.free(content);

    var parser = try Parser.initFromBuffer(testing.allocator, content);
    defer parser.deinit();

    const rootNode = try parser.parse();
    defer rootNode.deinit();

    try testing.expectEqual(22, rootNode.definitions.len);
    try testing.expectEqual(2, rootNode.definitions[2].unionTypeDefinition.types.len);
    try testing.expectEqual(OperationType.query, rootNode.definitions[11].operationDefinition.operation);

    const objectTypeExtension = rootNode.definitions[13].objectTypeExtension;
    try testing.expectEqual(1, objectTypeExtension.directives.len);
    try testing.expectEqual(2, objectTypeExtension.fields.len);

    const interfaceTypeExtension = rootNode.definitions[19].interfaceTypeExtension;
    try testing.expectEqual(1, interfaceTypeExtension.interfaces.len);
    try testing.expectEqualStrings("NewInterface", interfaceTypeExtension.interfaces[0].type.namedType.name);
    try testing.expectEqual(1, interfaceTypeExtension.directives.len);
    try testing.expectEqualStrings("someDirective", interfaceTypeExtension.directives[0].name);
    try testing.expectEqual(2, interfaceTypeExtension.fields.len);
    try testing.expectEqualStrings("newField", interfaceTypeExtension.fields[0].name);
    try testing.expectEqualStrings("anotherField", interfaceTypeExtension.fields[1].name);

    const unionTypeExtension = rootNode.definitions[20].unionTypeExtension;
    try testing.expectEqual(1, unionTypeExtension.directives.len);
    try testing.expectEqualStrings("someDirective", unionTypeExtension.directives[0].name);
    try testing.expectEqual(2, unionTypeExtension.types.len);
    try testing.expectEqualStrings("NewType", unionTypeExtension.types[0].namedType.name);
    try testing.expectEqualStrings("AnotherType", unionTypeExtension.types[1].namedType.name);

    const scalarTypeExtension = rootNode.definitions[21].scalarTypeExtension;
    try testing.expectEqualStrings("DateTime", scalarTypeExtension.name);
    try testing.expectEqual(2, scalarTypeExtension.directives.len);
    try testing.expectEqualStrings("someDirective", scalarTypeExtension.directives[0].name);
    try testing.expectEqualStrings("anotherDirective", scalarTypeExtension.directives[1].name);
}

test "e2e-print-text" {
    const content = try getFileContent("tests/parser.e2e.graphql", testing.allocator);
    defer testing.allocator.free(content);

    var parser = try Parser.initFromBuffer(testing.allocator, content);
    defer parser.deinit();

    const rootNode = try parser.parse();
    defer rootNode.deinit();

    var printer = try Printer.init(testing.allocator, rootNode);
    const text = try printer.getText();
    defer testing.allocator.free(text);

    const expectedText = try getFileContent("tests/parser.e2e.snapshot.txt", testing.allocator);
    defer testing.allocator.free(expectedText);

    const normalizedText = normalizeLineEndings(testing.allocator, text);
    defer testing.allocator.free(normalizedText);
    const normalizedExpectedText = normalizeLineEndings(testing.allocator, expectedText);
    defer testing.allocator.free(normalizedExpectedText);

    try testing.expectEqualStrings(normalizedExpectedText, normalizedText);
}

test "e2e-print-graphql" {
    const content = try getFileContent("tests/parser.e2e.graphql", testing.allocator);
    defer testing.allocator.free(content);

    var parser = try Parser.initFromBuffer(testing.allocator, content);
    defer parser.deinit();

    const rootNode = try parser.parse();
    defer rootNode.deinit();

    var printer = try Printer.init(testing.allocator, rootNode);
    const text = try printer.getGql();
    defer testing.allocator.free(text);

    const expectedText = try getFileContent("tests/parser.e2e.snapshot.graphql", testing.allocator);
    defer testing.allocator.free(expectedText);

    const normalizedText = normalizeLineEndings(testing.allocator, text);
    defer testing.allocator.free(normalizedText);
    const normalizedExpectedText = normalizeLineEndings(testing.allocator, expectedText);
    defer testing.allocator.free(normalizedExpectedText);

    try testing.expectEqualStrings(normalizedExpectedText, normalizedText);
}
