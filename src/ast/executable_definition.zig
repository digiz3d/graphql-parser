const FragmentDefinition = @import("fragment_definition.zig").FragmentDefinition;
const OperationDefinition = @import("operation_definition.zig").OperationDefinition;
const SchemaDefinition = @import("schema_definition.zig").SchemaDefinition;
const ObjectTypeDefinition = @import("object_type_definition.zig").ObjectTypeDefinition;
const UnionTypeDefinition = @import("union_type_definition.zig").UnionTypeDefinition;
const ScalarTypeDefinition = @import("scalar_type_definition.zig").ScalarTypeDefinition;
const DirectiveDefinition = @import("directive_definition.zig").DirectiveDefinition;
const InterfaceTypeDefinition = @import("interface_type_definition.zig").InterfaceTypeDefinition;
const SchemaExtension = @import("schema_extension.zig").SchemaExtension;
const ObjectTypeExtension = @import("object_type_extension.zig").ObjectTypeExtension;
const EnumTypeDefinition = @import("enum_type_definition.zig").EnumTypeDefinition;

pub const ExecutableDefinition = union(enum) {
    fragmentDefinition: FragmentDefinition,
    operationDefinition: OperationDefinition,
    schemaDefinition: SchemaDefinition,
    objectTypeDefinition: ObjectTypeDefinition,
    unionTypeDefinition: UnionTypeDefinition,
    scalarTypeDefinition: ScalarTypeDefinition,
    directiveDefinition: DirectiveDefinition,
    interfaceTypeDefinition: InterfaceTypeDefinition,
    schemaExtension: SchemaExtension,
    objectTypeExtension: ObjectTypeExtension,
    enumTypeDefinition: EnumTypeDefinition,

    pub fn printAST(self: ExecutableDefinition, indent: usize) void {
        switch (self) {
            inline else => |value| value.printAST(indent),
        }
    }

    pub fn deinit(self: ExecutableDefinition) void {
        switch (self) {
            inline else => |value| value.deinit(),
        }
    }
};
