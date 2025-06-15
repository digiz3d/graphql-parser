const std = @import("std");
const Allocator = std.mem.Allocator;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

const Argument = @import("arguments.zig").InputValueDefinition;
const Directive = @import("directive.zig").Directive;
const SelectionSet = @import("selection_set.zig").SelectionSet;

pub const Field = struct {
    allocator: Allocator,
    name: []const u8,
    alias: ?[]const u8,
    arguments: []Argument,
    directives: []Directive,
    selectionSet: ?SelectionSet,

    pub fn printAST(self: Field, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- FieldData\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        if (self.alias != null) {
            std.debug.print("{s}  alias = {?s}\n", .{ spaces, if (self.alias.?.len > 0) self.alias else "none" });
        } else {
            std.debug.print("{s}  alias = null\n", .{spaces});
        }
        std.debug.print("{s}  arguments: {d}\n", .{ spaces, self.arguments.len });
        for (self.arguments) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
        if (self.selectionSet != null) {
            std.debug.print("{s}  selectionSet: \n", .{spaces});
            self.selectionSet.?.printAST(indent + 1);
        } else {
            std.debug.print("{s}  selectionSet: null\n", .{spaces});
        }
    }

    pub fn deinit(self: Field) void {
        self.allocator.free(self.name);
        if (self.alias != null) {
            self.allocator.free(self.alias.?);
        }
        for (self.arguments) |item| {
            item.deinit();
        }
        self.allocator.free(self.arguments);
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        if (self.selectionSet != null) {
            self.selectionSet.?.deinit();
        }
    }
};
