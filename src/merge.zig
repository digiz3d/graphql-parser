const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Document = @import("ast/document.zig").Document;
const Token = @import("tokenizer.zig").Token;
const ExecutableDefinition = @import("ast/executable_definition.zig").ExecutableDefinition;
const getFileContent = @import("utils/utils.zig").getFileContent;
const Parser = @import("parser.zig").Parser;
const Printer = @import("printer.zig").Printer;

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

    pub fn mergeIntoSingleDocument(self: *Merger, documents: []const Document) MergeError!Document {
        var mergedDocument = Document{
            .allocator = self.allocator,
            .definitions = ArrayList(ExecutableDefinition).init(self.allocator),
        };

        for (documents) |document| {
            for (document.definitions.items) |definition| {
                mergedDocument.definitions.append(definition) catch return MergeError.UnexpectedMemoryError;
            }
        }

        return mergedDocument;
    }
};

pub fn main() !void {
    const filesToParse = [_][]const u8{
        "benchmark/graphql-definitions/base.graphql",
        "benchmark/graphql-definitions/extend.graphql",
        "benchmark/graphql-definitions/query.graphql",
    };

    var documents = ArrayList(Document).init(std.heap.page_allocator);

    for (filesToParse) |file| {
        const content = getFileContent(file, std.heap.page_allocator) catch return;
        defer std.heap.page_allocator.free(content);

        var parser = try Parser.initFromBuffer(std.heap.page_allocator, content);
        defer parser.deinit();

        const document = try parser.parse();
        documents.append(document) catch return;
    }

    var merger = Merger.init(std.heap.page_allocator);
    const mergedDocument = try merger.mergeIntoSingleDocument(try documents.toOwnedSlice());

    var printer = try Printer.init(std.heap.page_allocator, mergedDocument);
    const gql = try printer.getGql();
    std.debug.print("{s}", .{gql});
}
