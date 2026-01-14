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
                return MergeError.UnexpectedMemoryError,
        }
    }

    pub fn mergeIntoSingleDocument(self: *Merger, documents: []const Document) MergeError!Document {
        var similarDefinitionsMap = std.StringHashMap(ArrayList(ExecutableDefinition)).init(self.allocator);
        defer similarDefinitionsMap.deinit();

        var similarDefinitionsNames = ArrayList([]const u8).init(self.allocator);
        defer similarDefinitionsNames.deinit();

        for (documents) |document| {
            for (document.definitions.items) |definition| {
                const definitionName = try self.makeDefinitionName(definition);

                if (!similarDefinitionsMap.contains(definitionName)) {
                    var similarDefinitions = ArrayList(ExecutableDefinition).init(self.allocator);
                    // TODO: clone the definition
                    similarDefinitions.append(definition) catch return MergeError.UnexpectedMemoryError;
                    similarDefinitionsMap.put(definitionName, similarDefinitions) catch return MergeError.UnexpectedMemoryError;
                    similarDefinitionsNames.append(definitionName) catch return MergeError.UnexpectedMemoryError;
                    print("added definition 1 \"{s}\"\n", .{definitionName});
                } else {
                    var similarDefinitions = similarDefinitionsMap.get(definitionName).?;
                    // TODO: clone the definition
                    similarDefinitions.append(definition) catch return MergeError.UnexpectedMemoryError;
                    similarDefinitionsMap.put(definitionName, similarDefinitions) catch return MergeError.UnexpectedMemoryError;
                    print("added definition 2 \"{s}\"\n", .{definitionName});
                }
            }
        }

        print("similarDefinitionsNames: {d}\n", .{similarDefinitionsNames.items.len});
        for (similarDefinitionsNames.items) |definition_name| {
            const definitions = similarDefinitionsMap.get(definition_name).?;
            print("definition \"{s}\" has {d} entries\n", .{ definition_name, definitions.items.len });
            for (definitions.items, 0..) |definition, index| {
                print("  [{d}] tag={s}\n", .{ index, @tagName(definition) });
            }
        }

        // for each document, recursively browse it and check if the item exists at the same level in the new document. if not, create it.
        // problem: each ExecutableDefinition is not easily mutable; I have to create a new one

        // lets make an array or array like list of similar definitions.
        // ["typeDefinition_name", "directive_name"]
        // {
        //     "typeDefinition_name": [Definition1, Definition2],
        //     "directive_name": [Definition3, Definition4],
        // }
        //

        // TODO: merge each array and add definition to the merged document

        return Document{
            .allocator = self.allocator,
            .definitions = ArrayList(ExecutableDefinition).init(self.allocator),
        };
    }
};

pub fn main() !void {
    const filesToParse = [_][]const u8{
        "benchmark/graphql-definitions/base.graphql",
        "benchmark/graphql-definitions/extend.graphql",
        "benchmark/graphql-definitions/query.graphql",
    };

    const alloc = std.heap.page_allocator;

    var documents = ArrayList(Document).init(alloc);

    for (filesToParse) |file| {
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
    // defer mergedDocument.deinit();

    var printer = try Printer.init(alloc, mergedDocument);
    const gql = try printer.getGql();
    defer alloc.free(gql);

    const outputFile = try std.fs.cwd().createFile("zig.generated.graphql", .{});
    defer outputFile.close();
    std.debug.print("gql: {s}\n", .{gql});
    // try outputFile.writeAll(gql);
}
