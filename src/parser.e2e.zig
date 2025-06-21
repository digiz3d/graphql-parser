const testing = @import("std").testing;
const Parser = @import("parser.zig").Parser;
const OperationType = @import("ast/operation_definition.zig").OperationType;

test "e2e-parse" {
    const doc =
        \\ "schema desc"
        \\ schema {
        \\   query: Query
        \\ }
        \\ 
        \\ #lol
        \\ 
        \\ "scalar desc"
        \\ scalar Lol @lol
        \\ 
        \\ """
        \\ union desc
        \\ """
        \\ union SomeUnion = SomeType | SomeOtherType
        \\ 
        \\ "object def desc"
        \\ type Query @lol {
        \\   "ok"
        \\   name("obj def arg desc" id: ID!, value: String = "default"): String
        \\ }
        \\ 
        \\ interface USBA {
        \\   a: A
        \\ }
        \\ 
        \\ interface USBC {
        \\   C: C
        \\ }
        \\ 
        \\ type Desktop implements USBA & USBC {
        \\   ok: String
        \\ }
        \\ 
        \\ type Laptop implements USBC {
        \\   ok: String
        \\ }
        \\ 
        \\ "directive desc 1"
        \\ directive @example(
        \\   "directive arg desc"
        \\   arg: Ok = 123 @lol
        \\   arg2: Ok
        \\ ) on FIELD | OBJECT
        \\ 
        \\ "directive desc 2"
        \\ directive @lol on FIELD
        \\ 
        \\ fragment SomeFragment on ok {
        \\   id
        \\ }
        \\ 
        \\ query SomeQuery($id: ok) @lolok(arg: { lol: { ok: [true] } }, arg2: Ok) {
        \\   ok @field1
        \\   ...SomeFragment @field2
        \\ }
        \\ 
        \\ extend schema @someDirective {
        \\   mutation: Mutation
        \\ }
        \\ 
        \\ extend type Laptop implements ok @someDirective {
        \\   "ok"
        \\   k: String @someOtherDirective
        \\   k2: String @someOtherDirective
        \\ }
        \\ 
        \\ enum SomeEnum {
        \\   SOME_VALUE
        \\   SOME_OTHER_VALUE
        \\ }
        \\ 
        \\ enum SomeEnum2 @ok {
        \\   SOME_VALUE @ok2
        \\   SOME_OTHER_VALUE @ok3
        \\ }
        \\ 
        \\ extend enum SomeEnum2 @ok {
        \\   SOME_NEW_VALUE @ok4
        \\ }
        \\ 
        \\ "input desc"
        \\ input SomeInput @someDirective {
        \\   "some field desc"
        \\   field: String = "Some default"
        \\ }
        \\ 
        \\ extend input Oki {
        \\   "okidoki"
        \\   okayyy: String!
        \\ }
        \\ 
        \\ extend interface USBA implements NewInterface @someDirective {
        \\   "new field desc"
        \\   newField: String
        \\   anotherField: Int!
        \\ }
        \\ 
        \\ extend union SomeUnion @someDirective = NewType | AnotherType
        \\ 
        \\ extend scalar DateTime @someDirective @anotherDirective
        \\ 
    ;

    var parser = Parser.init(testing.allocator);

    const rootNode = try parser.parse(doc);
    defer rootNode.deinit();

    try testing.expectEqual(22, rootNode.definitions.items.len);
    try testing.expectEqual(2, rootNode.definitions.items[2].unionTypeDefinition.types.len);
    try testing.expectEqual(OperationType.query, rootNode.definitions.items[11].operationDefinition.operation);

    const objectTypeExtension = rootNode.definitions.items[13].objectTypeExtension;
    try testing.expectEqual(1, objectTypeExtension.directives.len);
    try testing.expectEqual(2, objectTypeExtension.fields.len);

    const interfaceTypeExtension = rootNode.definitions.items[19].interfaceTypeExtension;
    try testing.expectEqual(1, interfaceTypeExtension.interfaces.len);
    try testing.expectEqualStrings("NewInterface", interfaceTypeExtension.interfaces[0].type.namedType.name);
    try testing.expectEqual(1, interfaceTypeExtension.directives.len);
    try testing.expectEqualStrings("someDirective", interfaceTypeExtension.directives[0].name);
    try testing.expectEqual(2, interfaceTypeExtension.fields.len);
    try testing.expectEqualStrings("newField", interfaceTypeExtension.fields[0].name);
    try testing.expectEqualStrings("anotherField", interfaceTypeExtension.fields[1].name);

    const unionTypeExtension = rootNode.definitions.items[20].unionTypeExtension;
    try testing.expectEqual(1, unionTypeExtension.directives.len);
    try testing.expectEqualStrings("someDirective", unionTypeExtension.directives[0].name);
    try testing.expectEqual(2, unionTypeExtension.types.len);
    try testing.expectEqualStrings("NewType", unionTypeExtension.types[0].namedType.name);
    try testing.expectEqualStrings("AnotherType", unionTypeExtension.types[1].namedType.name);

    const scalarTypeExtension = rootNode.definitions.items[21].scalarTypeExtension;
    try testing.expectEqualStrings("DateTime", scalarTypeExtension.name);
    try testing.expectEqual(2, scalarTypeExtension.directives.len);
    try testing.expectEqualStrings("someDirective", scalarTypeExtension.directives[0].name);
    try testing.expectEqualStrings("anotherDirective", scalarTypeExtension.directives[1].name);
}
