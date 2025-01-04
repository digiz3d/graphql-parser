const std = @import("std");
const node = @import("./index.zig");
const input = @import("../input_value.zig");
const makeSpaceFromNumber = @import("../utils/utils.zig").makeSpaceFromNumber;

const parser = @import("../parser.zig");
const OperationType = parser.OperationType;

pub const OperationDefinition = struct {
    allocator: std.mem.Allocator,
    name: ?[]const u8,
    operation: OperationType,
    directives: []node.Directive,
    variableDefinitions: []node.VariableDefinition,
    selectionSet: node.SelectionSet,

    pub fn printAST(self: OperationDefinition, indent: usize) void {
        const spaces = makeSpaceFromNumber(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- OperationDefinition\n", .{spaces});
        std.debug.print("{s}  operation = {s}\n", .{ spaces, switch (self.operation) {
            OperationType.query => "query",
            OperationType.mutation => "mutation",
            OperationType.subscription => "subscription",
        } });
        std.debug.print("{s}  name = {?s}\n", .{ spaces, self.name });
        std.debug.print("{s}  variableDefinitions: {d}\n", .{ spaces, self.variableDefinitions.len });
        for (self.variableDefinitions) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  selectionSet: \n", .{spaces});
        self.selectionSet.printAST(indent + 1);
    }

    pub fn deinit(self: OperationDefinition) void {
        if (self.name != null) {
            self.allocator.free(self.name.?);
        }
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        for (self.variableDefinitions) |item| {
            item.deinit();
        }
        self.allocator.free(self.variableDefinitions);
        self.selectionSet.deinit();
    }
};
