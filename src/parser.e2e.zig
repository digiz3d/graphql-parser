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
    ;

    var parser = Parser.init(testing.allocator);

    const rootNode = try parser.parse(doc);
    defer rootNode.deinit();

    try testing.expectEqual(19, rootNode.definitions.items.len);
    try testing.expectEqual(2, rootNode.definitions.items[2].unionTypeDefinition.types.len);
    try testing.expectEqual(OperationType.query, rootNode.definitions.items[11].operationDefinition.operation);

    try testing.expectEqual(1, rootNode.definitions.items[13].objectTypeExtension.directives.len);
    try testing.expectEqual(2, rootNode.definitions.items[13].objectTypeExtension.fields.len);
}
