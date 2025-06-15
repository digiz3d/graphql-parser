const FragmentDefinition = @import("fragment_definition.zig").FragmentDefinition;
const OperationDefinition = @import("operation_definition.zig").OperationDefinition;
const SchemaDefinition = @import("schema_definition.zig").SchemaDefinition;
const ObjectTypeDefinition = @import("object_type_definition.zig").ObjectTypeDefinition;
const UnionTypeDefinition = @import("union_type_definition.zig").UnionTypeDefinition;

pub const ExecutableDefinition = union(enum) {
    fragment: FragmentDefinition,
    operation: OperationDefinition,
    schema: SchemaDefinition,
    objectTypeDefinition: ObjectTypeDefinition,
    unionTypeDefinition: UnionTypeDefinition,

    pub fn printAST(self: ExecutableDefinition, indent: usize) void {
        switch (self) {
            ExecutableDefinition.fragment => self.fragment.printAST(indent),
            ExecutableDefinition.operation => self.operation.printAST(indent),
            ExecutableDefinition.schema => self.schema.printAST(indent),
            ExecutableDefinition.objectTypeDefinition => self.objectTypeDefinition.printAST(indent),
            ExecutableDefinition.unionTypeDefinition => self.unionTypeDefinition.printAST(indent),
        }
    }

    pub fn deinit(self: ExecutableDefinition) void {
        switch (self) {
            ExecutableDefinition.fragment => self.fragment.deinit(),
            ExecutableDefinition.operation => self.operation.deinit(),
            ExecutableDefinition.schema => self.schema.deinit(),
            ExecutableDefinition.objectTypeDefinition => self.objectTypeDefinition.deinit(),
            ExecutableDefinition.unionTypeDefinition => self.unionTypeDefinition.deinit(),
        }
    }
};
