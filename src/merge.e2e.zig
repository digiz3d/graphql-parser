const std = @import("std");
const testing = @import("std").testing;
const Parser = @import("parse.zig").Parser;
const Merger = @import("merge.zig").Merger;
const getFileContent = @import("utils/utils.zig").getFileContent;
const ArrayList = std.ArrayList;
const Document = @import("ast/document.zig").Document;
const Printer = @import("print.zig").Printer;
const normalizeLineEndings = @import("utils/utils.zig").normalizeLineEndings;

test "e2e-merge" {
    const alloc = std.testing.allocator;
    const typeDefsDir = "tests/e2e-merge";

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

    const expectedText = try getFileContent("tests/merger.e2e.snapshot.graphql", testing.allocator);
    defer testing.allocator.free(expectedText);

    const normalizedText = normalizeLineEndings(testing.allocator, gql);
    defer testing.allocator.free(normalizedText);
    const normalizedExpectedText = normalizeLineEndings(testing.allocator, expectedText);
    defer testing.allocator.free(normalizedExpectedText);

    try testing.expectEqualStrings(normalizedExpectedText, normalizedText);
}
