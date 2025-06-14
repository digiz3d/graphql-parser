const FragmentDefinition = @import("fragment_definition.zig").FragmentDefinition;
const OperationDefinition = @import("operation_definition.zig").OperationDefinition;
const SchemaDefinition = @import("schema_definition.zig").SchemaDefinition;

pub const ExecutableDefinition = union(enum) {
    fragment: FragmentDefinition,
    operation: OperationDefinition,
    schema: SchemaDefinition,

    pub fn printAST(self: ExecutableDefinition, indent: usize) void {
        switch (self) {
            ExecutableDefinition.fragment => self.fragment.printAST(indent),
            ExecutableDefinition.operation => self.operation.printAST(indent),
            ExecutableDefinition.schema => self.schema.printAST(indent),
        }
    }

    pub fn deinit(self: ExecutableDefinition) void {
        switch (self) {
            ExecutableDefinition.fragment => self.fragment.deinit(),
            ExecutableDefinition.operation => self.operation.deinit(),
            ExecutableDefinition.schema => self.schema.deinit(),
        }
    }
};
