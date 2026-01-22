const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Document = @import("ast/document.zig").Document;
const Token = @import("tokenizer.zig").Token;
const ExecutableDefinition = @import("ast/executable_definition.zig").ExecutableDefinition;
const getFileContent = @import("utils/utils.zig").getFileContent;
const Parser = @import("parser.zig").Parser;
const Printer = @import("printer.zig").Printer;
const mergeIntoObjectTypeDefinition = @import("ast/object_type_definition.zig").mergeIntoObjectTypeDefinition;
const print = std.debug.print;
const ObjectTypeDefinition = @import("ast/object_type_definition.zig").ObjectTypeDefinition;
const ObjectTypeExtension = @import("ast/object_type_extension.zig").ObjectTypeExtension;
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
            else => return std.fmt.allocPrint(self.allocator, "unknownDefinition_{s}", .{@tagName(definition)}) catch
                MergeError.UnexpectedMemoryError,
        }
    }

    pub fn mergeIntoSingleDocument(self: *Merger, documents: []const Document) MergeError!Document {
        var similarDefinitionsMap = std.StringHashMap(ArrayList(ExecutableDefinition)).init(self.allocator);
        defer similarDefinitionsMap.deinit();

        for (documents) |document| {
            for (document.definitions) |definition| {
                const definitionName = try self.makeDefinitionName(definition);

                if (!similarDefinitionsMap.contains(definitionName)) {
                    var ar = ArrayList(ExecutableDefinition).init(self.allocator);
                    ar.append(definition) catch return MergeError.UnexpectedMemoryError;
                    similarDefinitionsMap.put(definitionName, ar) catch return MergeError.UnexpectedMemoryError;
                } else {
                    var ar = similarDefinitionsMap.get(definitionName).?;
                    ar.append(definition) catch return MergeError.UnexpectedMemoryError;
                    similarDefinitionsMap.put(definitionName, ar) catch return MergeError.UnexpectedMemoryError;
                }
            }
        }
        // data structure is like this:
        // {
        //   "objectTypeDefinition_Object": [objectTypeExtension_obj1, objectTypeDefinition_obj2],
        //   "objectTypeDefinition_Query": [objectTypeDefinition_obj3, objectTypeExtension_obj4],
        // }

        var mergedDefinitions = ArrayList(ExecutableDefinition).init(self.allocator);
        errdefer mergedDefinitions.deinit();
        var unmergeableDefinitions = ArrayList(ExecutableDefinition).init(self.allocator);
        defer unmergeableDefinitions.deinit();

        var iter = similarDefinitionsMap.iterator();

        while (iter.next()) |entry| {
            const similarDefinitions = entry.value_ptr.*;

            switch (similarDefinitions.items[0]) {
                .objectTypeDefinition, .objectTypeExtension => {
                    var objectTypeDefinitions = ArrayList(ObjectTypeDefinition).init(self.allocator);
                    for (similarDefinitions.items) |definition| {
                        objectTypeDefinitions.append(switch (definition) {
                            .objectTypeDefinition => |def| def,
                            .objectTypeExtension => |ext| ObjectTypeDefinition.fromExtension(ext),
                            else => unreachable,
                        }) catch return MergeError.UnexpectedMemoryError;
                    }
                    const mergedDefinition = try mergeObjectTypeDefinitions(self, objectTypeDefinitions.toOwnedSlice() catch return MergeError.UnexpectedMemoryError);
                    mergedDefinitions.append(ExecutableDefinition{ .objectTypeDefinition = mergedDefinition }) catch return MergeError.UnexpectedMemoryError;
                },
                .operationDefinition => {
                    unmergeableDefinitions.append(similarDefinitions.items[0]) catch return MergeError.UnexpectedMemoryError;
                },
                else => continue, // TODO: handle other types of definitions
            }
        }

        if (unmergeableDefinitions.items.len > 0) {
            print("unmergeableDefinitions: {d}\n", .{unmergeableDefinitions.items.len});
            for (unmergeableDefinitions.items) |definition| {
                print(" - {s} ({s})\n", .{
                    @tagName(definition), switch (definition) {
                        .operationDefinition => |operationDefinition| operationDefinition.name.?,
                        else => unreachable, // TODO: handle other types of definitions, like fragment definitions
                    },
                });
            }
        }

        return Document{
            .allocator = self.allocator,
            .definitions = mergedDefinitions.toOwnedSlice() catch return MergeError.UnexpectedMemoryError,
        };
    }
};

fn mergeObjectTypeDefinitions(self: *Merger, objectTypeDefinitions: []const ObjectTypeDefinition) MergeError!ObjectTypeDefinition {
    var name: ?[]const u8 = null;
    var description: ?[]const u8 = null;
    var interfaces = ArrayList(Interface).init(self.allocator);
    var directives = ArrayList(Directive).init(self.allocator);
    var fields = ArrayList(FieldDefinition).init(self.allocator);

    for (objectTypeDefinitions) |objectTypeDef| {
        if (name == null) {
            name = objectTypeDef.name;
        }
        if (description == null) {
            description = objectTypeDef.description;
        }
        interfaces.appendSlice(objectTypeDef.interfaces) catch return MergeError.UnexpectedMemoryError;
        directives.appendSlice(objectTypeDef.directives) catch return MergeError.UnexpectedMemoryError;
        fields.appendSlice(objectTypeDef.fields) catch return MergeError.UnexpectedMemoryError;
    }

    return ObjectTypeDefinition{
        ._is_merge_result = true,
        .allocator = self.allocator,
        .name = name.?,
        .interfaces = interfaces.toOwnedSlice() catch return MergeError.UnexpectedMemoryError,
        .directives = directives.toOwnedSlice() catch return MergeError.UnexpectedMemoryError,
        .fields = fields.toOwnedSlice() catch return MergeError.UnexpectedMemoryError,
        .description = if (description != null) description.? else null,
    };
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const typeDefsDir = "tests/e2e-merge";

    var dir = try std.fs.cwd().openDir(typeDefsDir, .{ .iterate = true });
    defer dir.close();

    var filesToParse = ArrayList([]const u8).init(alloc);
    defer {
        for (filesToParse.items) |path| {
            alloc.free(path);
        }
        filesToParse.deinit();
    }

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind == .file) {
            const path = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ typeDefsDir, entry.name });
            try filesToParse.append(path);
        }
    }

    var documents = ArrayList(Document).init(alloc);

    for (filesToParse.items) |file| {
        const content = getFileContent(file, alloc) catch return;
        defer alloc.free(content);

        var parser = try Parser.initFromBuffer(alloc, content);
        defer parser.deinit();

        const document = try parser.parse();
        documents.append(document) catch return;
    }

    var merger = Merger.init(alloc);
    const documentsSlice = try documents.toOwnedSlice();
    defer {
        for (documentsSlice) |document| {
            document.deinit();
        }
        alloc.free(documentsSlice);
    }
    const mergedDocument = try merger.mergeIntoSingleDocument(documentsSlice);
    defer mergedDocument.deinit();

    var printer = try Printer.init(alloc, mergedDocument);
    const gql = try printer.getGql();
    defer alloc.free(gql);

    const outputFile = try std.fs.cwd().createFile("zig.generated.graphql", .{});
    defer outputFile.close();
    try outputFile.writeAll(gql);
}
