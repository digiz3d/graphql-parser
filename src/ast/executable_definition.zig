const FragmentDefinition = @import("fragment_definition.zig").FragmentDefinition;
const OperationDefinition = @import("operation_definition.zig").OperationDefinition;

pub const ExecutableDefinition = union(enum) {
    fragment: FragmentDefinition,
    operation: OperationDefinition,

    pub fn printAST(self: ExecutableDefinition, indent: usize) void {
        switch (self) {
            ExecutableDefinition.fragment => self.fragment.printAST(indent),
            ExecutableDefinition.operation => self.operation.printAST(indent),
        }
    }

    pub fn deinit(self: ExecutableDefinition) void {
        switch (self) {
            ExecutableDefinition.fragment => self.fragment.deinit(),
            ExecutableDefinition.operation => self.operation.deinit(),
        }
    }
};
