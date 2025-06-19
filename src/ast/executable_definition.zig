const FragmentDefinition = @import("fragment_definition.zig").FragmentDefinition;
const OperationDefinition = @import("operation_definition.zig").OperationDefinition;
const SchemaDefinition = @import("schema_definition.zig").SchemaDefinition;
const ObjectTypeDefinition = @import("object_type_definition.zig").ObjectTypeDefinition;
const UnionTypeDefinition = @import("union_type_definition.zig").UnionTypeDefinition;
const ScalarTypeDefinition = @import("scalar_type_definition.zig").ScalarTypeDefinition;
const DirectiveDefinition = @import("directive_definition.zig").DirectiveDefinition;
const InterfaceTypeDefinition = @import("interface_type_definition.zig").InterfaceTypeDefinition;

pub const ExecutableDefinition = union(enum) {
    fragmentDefinition: FragmentDefinition,
    operationDefinition: OperationDefinition,
    schemaDefinition: SchemaDefinition,
    objectTypeDefinition: ObjectTypeDefinition,
    unionTypeDefinition: UnionTypeDefinition,
    scalarTypeDefinition: ScalarTypeDefinition,
    directiveDefinition: DirectiveDefinition,
    interfaceTypeDefinition: InterfaceTypeDefinition,

    pub fn printAST(self: ExecutableDefinition, indent: usize) void {
        switch (self) {
            ExecutableDefinition.fragmentDefinition => self.fragmentDefinition.printAST(indent),
            ExecutableDefinition.operationDefinition => self.operationDefinition.printAST(indent),
            ExecutableDefinition.schemaDefinition => self.schemaDefinition.printAST(indent),
            ExecutableDefinition.objectTypeDefinition => self.objectTypeDefinition.printAST(indent),
            ExecutableDefinition.unionTypeDefinition => self.unionTypeDefinition.printAST(indent),
            ExecutableDefinition.scalarTypeDefinition => self.scalarTypeDefinition.printAST(indent),
            ExecutableDefinition.directiveDefinition => self.directiveDefinition.printAST(indent),
            ExecutableDefinition.interfaceTypeDefinition => self.interfaceTypeDefinition.printAST(indent),
        }
    }

    pub fn deinit(self: ExecutableDefinition) void {
        switch (self) {
            ExecutableDefinition.fragmentDefinition => self.fragmentDefinition.deinit(),
            ExecutableDefinition.operationDefinition => self.operationDefinition.deinit(),
            ExecutableDefinition.schemaDefinition => self.schemaDefinition.deinit(),
            ExecutableDefinition.objectTypeDefinition => self.objectTypeDefinition.deinit(),
            ExecutableDefinition.unionTypeDefinition => self.unionTypeDefinition.deinit(),
            ExecutableDefinition.scalarTypeDefinition => self.scalarTypeDefinition.deinit(),
            ExecutableDefinition.directiveDefinition => self.directiveDefinition.deinit(),
            ExecutableDefinition.interfaceTypeDefinition => self.interfaceTypeDefinition.deinit(),
        }
    }
};
