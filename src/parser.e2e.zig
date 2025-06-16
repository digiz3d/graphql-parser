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
        \\ query SomeQuery($id: ok) @lolok(arg: Ok, arg2: Ok) {
        \\   ok @field1
        \\   ...SomeFragment @field2
        \\ }
    ;

    var parser = Parser.init(testing.allocator);

    const rootNode = try parser.parse(doc);
    defer rootNode.deinit();

    try testing.expectEqual(8, rootNode.definitions.items.len);
    try testing.expectEqual(2, rootNode.definitions.items[2].unionTypeDefinition.types.len);
    try testing.expectEqual(OperationType.query, rootNode.definitions.items[7].operationDefinition.operation);
}
