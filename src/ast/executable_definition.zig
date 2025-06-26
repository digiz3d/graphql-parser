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
const EnumTypeExtension = @import("enum_type_extension.zig").EnumTypeExtension;
const InputObjectTypeDefinition = @import("input_object_type_definition.zig").InputObjectTypeDefinition;
const InputObjectTypeExtension = @import("input_object_type_extension.zig").InputObjectTypeExtension;
const InterfaceTypeExtension = @import("interface_type_extension.zig").InterfaceTypeExtension;
const UnionTypeExtension = @import("union_type_extension.zig").UnionTypeExtension;
const ScalarTypeExtension = @import("scalar_type_extension.zig").ScalarTypeExtension;

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
    enumTypeExtension: EnumTypeExtension,
    inputObjectTypeDefinition: InputObjectTypeDefinition,
    inputObjectTypeExtension: InputObjectTypeExtension,
    interfaceTypeExtension: InterfaceTypeExtension,
    unionTypeExtension: UnionTypeExtension,
    scalarTypeExtension: ScalarTypeExtension,

    pub fn deinit(self: ExecutableDefinition) void {
        switch (self) {
            inline else => |value| value.deinit(),
        }
    }
};
