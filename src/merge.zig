const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Document = @import("ast/document.zig").Document;
const ExecutableDefinition = @import("ast/executable_definition.zig").ExecutableDefinition;
const Type = @import("ast/type.zig").Type;
const InputValueDefinition = @import("ast/input_value_definition.zig").InputValueDefinition;
const InputObjectTypeDefinition = @import("ast/input_object_type_definition.zig").InputObjectTypeDefinition;
const InterfaceTypeDefinition = @import("ast/interface_type_definition.zig").InterfaceTypeDefinition;
const ObjectTypeDefinition = @import("ast/object_type_definition.zig").ObjectTypeDefinition;
const ObjectTypeExtension = @import("ast/object_type_extension.zig").ObjectTypeExtension;
const UnionTypeDefinition = @import("ast/union_type_definition.zig").UnionTypeDefinition;
const UnionTypeExtension = @import("ast/union_type_extension.zig").UnionTypeExtension;
const Interface = @import("ast/interface.zig").Interface;
const Directive = @import("ast/directive.zig").Directive;
const FieldDefinition = @import("ast/field_definition.zig").FieldDefinition;

pub const MergeError = error{
    UnexpectedMemoryError,
};

pub const Merger = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) Merger {
        return Merger{
            .allocator = allocator,
        };
    }

    fn makeDefinitionName(self: *Merger, definition: ExecutableDefinition) MergeError![]const u8 {
        switch (definition) {
            .objectTypeDefinition => |objectTypeDefinition| {
                return std.fmt.allocPrint(self.allocator, "objectTypeDefinition_{s}", .{objectTypeDefinition.name}) catch
                    return MergeError.UnexpectedMemoryError;
            },
            .objectTypeExtension => |objectTypeExtension| {
                return std.fmt.allocPrint(self.allocator, "objectTypeDefinition_{s}", .{objectTypeExtension.name}) catch
                    return MergeError.UnexpectedMemoryError;
            },
            .unionTypeDefinition => |unionTypeDefinition| {
                return std.fmt.allocPrint(self.allocator, "unionTypeDefinition_{s}", .{unionTypeDefinition.name}) catch
                    return MergeError.UnexpectedMemoryError;
            },
            .unionTypeExtension => |unionTypeExtension| {
                return std.fmt.allocPrint(self.allocator, "unionTypeDefinition_{s}", .{unionTypeExtension.name}) catch
                    return MergeError.UnexpectedMemoryError;
            },
            .interfaceTypeDefinition => |interfaceTypeDefinition| {
                return std.fmt.allocPrint(self.allocator, "interfaceTypeDefinition_{s}", .{interfaceTypeDefinition.name}) catch
                    return MergeError.UnexpectedMemoryError;
            },
            .interfaceTypeExtension => |interfaceTypeExtension| {
                return std.fmt.allocPrint(self.allocator, "interfaceTypeDefinition_{s}", .{interfaceTypeExtension.name}) catch
                    return MergeError.UnexpectedMemoryError;
            },
            .inputObjectTypeDefinition => |inputObjectTypeDefinition| {
                return std.fmt.allocPrint(self.allocator, "inputObjectTypeDefinition_{s}", .{inputObjectTypeDefinition.name}) catch
                    return MergeError.UnexpectedMemoryError;
            },
            .inputObjectTypeExtension => |inputObjectTypeExtension| {
                return std.fmt.allocPrint(self.allocator, "inputObjectTypeDefinition_{s}", .{inputObjectTypeExtension.name}) catch
                    return MergeError.UnexpectedMemoryError;
            },
            else => return std.fmt.allocPrint(self.allocator, "unknownDefinition_{s}", .{@tagName(definition)}) catch
                MergeError.UnexpectedMemoryError,
        }
    }

    pub fn mergeIntoSingleDocument(self: *Merger, documents: []const Document) MergeError!Document {
        // data structure is like:
        // {
        //   "objectTypeDefinition_Object": [objectTypeExtension_obj1, objectTypeDefinition_obj2],
        //   "objectTypeDefinition_Query": [objectTypeDefinition_obj3, objectTypeExtension_obj4],
        // }
        var similarDefinitionsMap: std.StringHashMap(ArrayList(ExecutableDefinition)) = .init(self.allocator);
        defer {
            var iter = similarDefinitionsMap.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                entry.value_ptr.deinit(self.allocator);
            }
            similarDefinitionsMap.deinit();
        }
        // allows iterating in the same order as the definitions were added
        var similarDefinitionsNames: std.ArrayList([]const u8) = .empty;
        defer similarDefinitionsNames.deinit(self.allocator);

        for (documents) |document| {
            for (document.definitions) |definition| {
                const definitionName = try self.makeDefinitionName(definition);

                if (similarDefinitionsMap.contains(definitionName)) {
                    var ar = similarDefinitionsMap.get(definitionName).?;
                    ar.append(self.allocator, definition) catch return MergeError.UnexpectedMemoryError;
                    similarDefinitionsMap.put(definitionName, ar) catch return MergeError.UnexpectedMemoryError;
                    self.allocator.free(definitionName);
                } else {
                    var ar: ArrayList(ExecutableDefinition) = .empty;
                    ar.append(self.allocator, definition) catch return MergeError.UnexpectedMemoryError;
                    similarDefinitionsMap.put(definitionName, ar) catch return MergeError.UnexpectedMemoryError;
                    similarDefinitionsNames.append(self.allocator, definitionName) catch return MergeError.UnexpectedMemoryError;
                }
            }
        }

        var mergedDefinitions: ArrayList(ExecutableDefinition) = .empty;
        errdefer mergedDefinitions.deinit(self.allocator);
        var unmergeableDefinitions: ArrayList(ExecutableDefinition) = .empty;
        defer unmergeableDefinitions.deinit(self.allocator);

        for (similarDefinitionsNames.items) |definitionName| {
            const similarDefinitions = similarDefinitionsMap.get(definitionName).?;

            switch (similarDefinitions.items[0]) {
                .objectTypeDefinition, .objectTypeExtension => {
                    var objectTypeDefinitions: ArrayList(ObjectTypeDefinition) = .empty;
                    defer objectTypeDefinitions.deinit(self.allocator);

                    for (similarDefinitions.items) |definition| {
                        objectTypeDefinitions.append(self.allocator, switch (definition) {
                            .objectTypeDefinition => |def| def,
                            .objectTypeExtension => |ext| ObjectTypeDefinition.fromExtension(ext),
                            else => unreachable,
                        }) catch return MergeError.UnexpectedMemoryError;
                    }
                    const mergedDefinition = try mergeObjectTypeDefinitions(self, objectTypeDefinitions);
                    mergedDefinitions.append(self.allocator, ExecutableDefinition{ .objectTypeDefinition = mergedDefinition }) catch return MergeError.UnexpectedMemoryError;
                },
                .unionTypeDefinition, .unionTypeExtension => {
                    var unionTypeDefinitions: ArrayList(UnionTypeDefinition) = .empty;
                    defer unionTypeDefinitions.deinit(self.allocator);

                    for (similarDefinitions.items) |definition| {
                        unionTypeDefinitions.append(self.allocator, switch (definition) {
                            .unionTypeDefinition => |def| def,
                            .unionTypeExtension => |ext| UnionTypeDefinition.fromExtension(ext),
                            else => unreachable,
                        }) catch return MergeError.UnexpectedMemoryError;
                    }
                    const mergedDefinition = try mergeUnionTypeDefinitions(self, unionTypeDefinitions);
                    mergedDefinitions.append(self.allocator, ExecutableDefinition{ .unionTypeDefinition = mergedDefinition }) catch return MergeError.UnexpectedMemoryError;
                },
                .interfaceTypeDefinition, .interfaceTypeExtension => {
                    var interfaceTypeDefinitions: ArrayList(InterfaceTypeDefinition) = .empty;
                    defer interfaceTypeDefinitions.deinit(self.allocator);

                    for (similarDefinitions.items) |definition| {
                        interfaceTypeDefinitions.append(self.allocator, switch (definition) {
                            .interfaceTypeDefinition => |def| def,
                            .interfaceTypeExtension => |ext| InterfaceTypeDefinition.fromExtension(ext),
                            else => unreachable,
                        }) catch return MergeError.UnexpectedMemoryError;
                    }

                    const mergedDefinition = try mergeInterfaceTypeDefinitions(self, interfaceTypeDefinitions);
                    mergedDefinitions.append(self.allocator, ExecutableDefinition{ .interfaceTypeDefinition = mergedDefinition }) catch return MergeError.UnexpectedMemoryError;
                },
                .inputObjectTypeDefinition, .inputObjectTypeExtension => {
                    var inputObjectTypeDefinitions: ArrayList(InputObjectTypeDefinition) = .empty;
                    defer inputObjectTypeDefinitions.deinit(self.allocator);

                    for (similarDefinitions.items) |definition| {
                        inputObjectTypeDefinitions.append(self.allocator, switch (definition) {
                            .inputObjectTypeDefinition => |def| def,
                            .inputObjectTypeExtension => |ext| InputObjectTypeDefinition.fromExtension(ext),
                            else => unreachable,
                        }) catch return MergeError.UnexpectedMemoryError;
                    }

                    const mergedDefinition = try mergeInputObjectTypeDefinitions(self, inputObjectTypeDefinitions);
                    mergedDefinitions.append(self.allocator, ExecutableDefinition{ .inputObjectTypeDefinition = mergedDefinition }) catch return MergeError.UnexpectedMemoryError;
                },
                .operationDefinition, .fragmentDefinition => {
                    unmergeableDefinitions.appendSlice(self.allocator, similarDefinitions.items) catch return MergeError.UnexpectedMemoryError;
                },
                else => continue, // TODO: handle other types of definitions
            }
        }

        if (unmergeableDefinitions.items.len > 0) {
            std.debug.print("unmergeableDefinitions: {d}\n", .{unmergeableDefinitions.items.len});
            for (unmergeableDefinitions.items) |definition| {
                std.debug.print(" - {s} ({s})\n", .{
                    @tagName(definition), switch (definition) {
                        .operationDefinition => |operationDefinition| operationDefinition.name.?,
                        .fragmentDefinition => |fragmentDefinition| fragmentDefinition.name,
                        else => unreachable, // TODO: handle other types of definitions, like fragment definitions
                    },
                });
            }
        }

        return Document{
            .allocator = self.allocator,
            .definitions = mergedDefinitions.toOwnedSlice(self.allocator) catch return MergeError.UnexpectedMemoryError,
        };
    }
};

fn mergeObjectTypeDefinitions(self: *Merger, objectTypeDefinitions: ArrayList(ObjectTypeDefinition)) MergeError!ObjectTypeDefinition {
    var name: ?[]const u8 = null;
    var description: ?[]const u8 = null;
    var interfaces: ArrayList(Interface) = .empty;
    var directives: ArrayList(Directive) = .empty;
    var fields: ArrayList(FieldDefinition) = .empty;

    for (objectTypeDefinitions.items) |objectTypeDef| {
        if (name == null) {
            name = objectTypeDef.name;
        }
        if (description == null) {
            description = objectTypeDef.description;
        }
        interfaces.appendSlice(self.allocator, objectTypeDef.interfaces) catch return MergeError.UnexpectedMemoryError;
        directives.appendSlice(self.allocator, objectTypeDef.directives) catch return MergeError.UnexpectedMemoryError;
        fields.appendSlice(self.allocator, objectTypeDef.fields) catch return MergeError.UnexpectedMemoryError;
    }

    return ObjectTypeDefinition{
        .allocator = self.allocator,
        .name = name.?,
        .interfaces = interfaces.toOwnedSlice(self.allocator) catch return MergeError.UnexpectedMemoryError,
        .directives = directives.toOwnedSlice(self.allocator) catch return MergeError.UnexpectedMemoryError,
        .fields = fields.toOwnedSlice(self.allocator) catch return MergeError.UnexpectedMemoryError,
        .description = if (description != null) description.? else null,
        ._is_merge_result = true,
    };
}

fn mergeUnionTypeDefinitions(self: *Merger, unionTypeDefinitions: ArrayList(UnionTypeDefinition)) MergeError!UnionTypeDefinition {
    var name: ?[]const u8 = null;
    var description: ?[]const u8 = null;
    var types: ArrayList(Type) = .empty;
    var directives: ArrayList(Directive) = .empty;

    for (unionTypeDefinitions.items) |unionTypeDef| {
        if (name == null) {
            name = unionTypeDef.name;
        }
        if (description == null) {
            description = unionTypeDef.description;
        }
        types.appendSlice(self.allocator, unionTypeDef.types) catch return MergeError.UnexpectedMemoryError;
        directives.appendSlice(self.allocator, unionTypeDef.directives) catch return MergeError.UnexpectedMemoryError;
    }

    return UnionTypeDefinition{
        .allocator = self.allocator,
        .name = name.?,
        .types = types.toOwnedSlice(self.allocator) catch return MergeError.UnexpectedMemoryError,
        .directives = directives.toOwnedSlice(self.allocator) catch return MergeError.UnexpectedMemoryError,
        .description = if (description != null) description.? else null,
        ._is_merge_result = true,
    };
}

fn mergeInterfaceTypeDefinitions(self: *Merger, interfaceTypeDefinitions: ArrayList(InterfaceTypeDefinition)) MergeError!InterfaceTypeDefinition {
    var name: ?[]const u8 = null;
    var description: ?[]const u8 = null;
    var interfaces: ArrayList(Interface) = .empty;
    var directives: ArrayList(Directive) = .empty;
    var fields: ArrayList(FieldDefinition) = .empty;

    for (interfaceTypeDefinitions.items) |interfaceTypeDef| {
        if (name == null) {
            name = interfaceTypeDef.name;
        }
        if (description == null) {
            description = interfaceTypeDef.description;
        }
        interfaces.appendSlice(self.allocator, interfaceTypeDef.interfaces) catch return MergeError.UnexpectedMemoryError;
        directives.appendSlice(self.allocator, interfaceTypeDef.directives) catch return MergeError.UnexpectedMemoryError;
        fields.appendSlice(self.allocator, interfaceTypeDef.fields) catch return MergeError.UnexpectedMemoryError;
    }

    return InterfaceTypeDefinition{
        .allocator = self.allocator,
        .name = name.?,
        .description = if (description != null) description.? else null,
        .interfaces = interfaces.toOwnedSlice(self.allocator) catch return MergeError.UnexpectedMemoryError,
        .directives = directives.toOwnedSlice(self.allocator) catch return MergeError.UnexpectedMemoryError,
        .fields = fields.toOwnedSlice(self.allocator) catch return MergeError.UnexpectedMemoryError,
        ._is_merge_result = true,
    };
}

fn mergeInputObjectTypeDefinitions(self: *Merger, inputObjectTypeDefinitions: ArrayList(InputObjectTypeDefinition)) MergeError!InputObjectTypeDefinition {
    var name: ?[]const u8 = null;
    var description: ?[]const u8 = null;
    var directives: ArrayList(Directive) = .empty;
    var fields: ArrayList(InputValueDefinition) = .empty;

    for (inputObjectTypeDefinitions.items) |inputObjectTypeDefinition| {
        if (name == null) {
            name = inputObjectTypeDefinition.name;
        }
        if (description == null) {
            description = inputObjectTypeDefinition.description;
        }
        directives.appendSlice(self.allocator, inputObjectTypeDefinition.directives) catch return MergeError.UnexpectedMemoryError;
        fields.appendSlice(self.allocator, inputObjectTypeDefinition.fields) catch return MergeError.UnexpectedMemoryError;
    }

    return InputObjectTypeDefinition{
        .allocator = self.allocator,
        .name = name.?,
        .description = if (description != null) description.? else null,
        .directives = directives.toOwnedSlice(self.allocator) catch return MergeError.UnexpectedMemoryError,
        .fields = fields.toOwnedSlice(self.allocator) catch return MergeError.UnexpectedMemoryError,
        ._is_merge_result = true,
    };
}
