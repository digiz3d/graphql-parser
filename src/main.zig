const std = @import("std");
const Parser = @import("parse.zig").Parser;
const parseArgs = @import("args.zig").parseArgs;
const getFileContent = @import("utils/utils.zig").getFileContent;
const Printer = @import("print.zig").Printer;
const Merger = @import("merge.zig").Merger;
const Document = @import("ast/document.zig").Document;
const strEq = @import("utils/utils.zig").strEq;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const command = try parseArgs(allocator);
    switch (command) {
        .ast => |astArgs| {
            if (astArgs.paths.len < 1) {
                std.debug.print("Error: No files provided\n", .{});
                std.debug.print("Usage: gqlt ast [input_paths...]\n", .{});
                return;
            }
            var documents: std.ArrayList(Document) = .empty;
            defer {
                for (documents.items) |document| {
                    document.deinit();
                }
                documents.deinit(allocator);
            }
            for (astArgs.paths) |file| {
                const content = getFileContent(file, allocator) catch {
                    std.debug.print("Error getting file content: {s}\n", .{file});
                    return;
                };
                defer allocator.free(content);

                var parser = try Parser.initFromBuffer(allocator, content);
                defer parser.deinit();

                const document = try parser.parse();
                defer document.deinit();

                var printer = try Printer.init(allocator, document);
                const gql = try printer.getText();
                defer allocator.free(gql);

                std.debug.print("{s}:\n{s}\n", .{ file, gql });
            }
        },
        .merge => |mergeArgs| {
            if (mergeArgs.paths.len < 2) {
                std.debug.print("Error: No files provided\n", .{});
                std.debug.print("Usage: gqlt merge [input_paths...] [output_path]\n", .{});
                return;
            }
            var timer = std.time.Timer.start() catch return;
            var documents: std.ArrayList(Document) = .empty;
            defer {
                for (documents.items) |document| {
                    document.deinit();
                }
                documents.deinit(allocator);
            }
            const destinationPath = mergeArgs.paths[mergeArgs.paths.len - 1];
            for (mergeArgs.paths[0 .. mergeArgs.paths.len - 1]) |file| {
                if (strEq(file, destinationPath)) {
                    std.debug.print("Warning: Destination file cannot be the same as the source file: {s}\n", .{file});
                    continue;
                }
                const content = getFileContent(file, allocator) catch return;
                defer allocator.free(content);

                var parser = try Parser.initFromBuffer(allocator, content);
                defer parser.deinit();

                const document = try parser.parse();
                documents.append(allocator, document) catch return;
            }

            var merger = Merger.init(allocator);
            const mergedDocument = try merger.mergeIntoSingleDocument(documents.items);
            defer mergedDocument.deinit();

            var printer = try Printer.init(allocator, mergedDocument);
            const gql = try printer.getGql();
            defer allocator.free(gql);

            const outputFile = try std.fs.cwd().createFile(destinationPath, .{});
            defer outputFile.close();
            try outputFile.writeAll(gql);
            const elapsed_ns = timer.read();
            const elapsed_ms = elapsed_ns / 1_000_000;
            std.debug.print("Merged {d} files in {d}ms\n", .{ documents.items.len, elapsed_ms });
        },
        .help => {
            std.log.info("Usage: gqlt <command>\n", .{});
            std.log.info("Commands:\n", .{});
            std.log.info("  ast: Print the AST of the given files", .{});
            std.log.info("  merge: Merge the given files into a single document", .{});
            std.log.info("  help: Print this help message", .{});
        },
    }
}
