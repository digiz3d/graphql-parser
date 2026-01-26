const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const gqlLib = @import("gql");
const Document = gqlLib.Document;
const getFileContent = gqlLib.getFileContent;
const Parser = gqlLib.Parser;
const Merger = gqlLib.Merger;
const Printer = gqlLib.Printer;

pub const MergeError = error{
    UnexpectedMemoryError,
};

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const typeDefsDir = "graphql-definitions";

    var dir = try std.fs.cwd().openDir(typeDefsDir, .{ .iterate = true });
    defer dir.close();

    var filesToParse: ArrayList([]const u8) = .empty;
    defer {
        for (filesToParse.items) |path| {
            alloc.free(path);
        }
        filesToParse.deinit(alloc);
    }

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind == .file) {
            const path = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ typeDefsDir, entry.name });
            try filesToParse.append(alloc, path);
        }
    }

    var documents: ArrayList(Document) = .empty;

    for (filesToParse.items) |file| {
        const content = getFileContent(file, alloc) catch return;
        defer alloc.free(content);

        var parser = try Parser.initFromBuffer(alloc, content);
        defer parser.deinit();

        const document = try parser.parse();
        documents.append(alloc, document) catch return;
    }

    var merger = Merger.init(alloc);
    const documentsSlice = try documents.toOwnedSlice(alloc);
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
