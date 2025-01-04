const node = @import("./index.zig");

pub const ExecutableDefinition = union(enum) {
    fragment: node.FragmentDefinition,
    operation: node.OperationDefinition,

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
