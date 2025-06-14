const std = @import("std");
const Allocator = std.mem.Allocator;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

const Directive = @import("directive.zig").Directive;
const SelectionSet = @import("selection_set.zig").SelectionSet;
const OperationTypeDefinition = @import("operation_type_definition.zig").OperationTypeDefinition;

pub const SchemaDefinition = struct {
    allocator: Allocator,
    directives: []Directive,
    operation_types: []OperationTypeDefinition,

    pub fn printAST(self: SchemaDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- SchemaDefinition\n", .{spaces});
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  operation_types: {d}\n", .{ spaces, self.operation_types.len });
        for (self.operation_types) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: SchemaDefinition) void {
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        for (self.operation_types) |item| {
            item.deinit();
        }
        self.allocator.free(self.operation_types);
    }
};
