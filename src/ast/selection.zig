const Field = @import("field.zig").Field;
const FragmentSpread = @import("fragment_spread.zig").FragmentSpread;
const InlineFragment = @import("inline_fragment.zig").InlineFragment;

pub const Selection = union(enum) {
    field: Field,
    fragmentSpread: FragmentSpread,
    inlineFragment: InlineFragment,

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
