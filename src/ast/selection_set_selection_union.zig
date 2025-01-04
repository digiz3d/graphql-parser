const node = @import("./index.zig");

pub const Selection = union(enum) {
    field: node.Field,
    fragmentSpread: node.FragmentSpread,
    inlineFragment: node.InlineFragment,

    pub fn printAST(self: Selection, indent: usize) void {
        switch (self) {
            Selection.field => self.field.printAST(indent),
            Selection.fragmentSpread => self.fragmentSpread.printAST(indent),
            Selection.inlineFragment => self.inlineFragment.printAST(indent),
        }
    }

    pub fn deinit(self: Selection) void {
        switch (self) {
            Selection.field => self.field.deinit(),
            Selection.fragmentSpread => self.fragmentSpread.deinit(),
            Selection.inlineFragment => self.inlineFragment.deinit(),
        }
    }
};
