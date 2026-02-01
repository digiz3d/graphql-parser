const std = @import("std");
const Allocator = std.mem.Allocator;
const strEq = @import("utils/utils.zig").strEq;

const MergeArgs = struct {
    paths: [][]const u8,
};

const PrintASTArgs = struct {
    paths: [][]const u8,
};

const HelpArgs = struct {};

const Command = union(enum) {
    ast: PrintASTArgs,
    merge: MergeArgs,
    help: HelpArgs,
};

const CLIError = error{
    InvalidCommand,
    MissingCommand,
    MissingInputFiles,
    MissingOutputFile,
    UnexpectedMemoryError,
};

pub fn parseArgs(allocator: Allocator) CLIError!Command {
    var argsIterator = std.process.argsWithAllocator(allocator) catch return CLIError.UnexpectedMemoryError;
    defer argsIterator.deinit();
    var result: Command = undefined;

    _ = argsIterator.next(); // skip program name

    const maybeCommand = argsIterator.next();
    if (maybeCommand == null) {
        return Command{ .help = HelpArgs{} };
    }
    const command = std.meta.stringToEnum(enum {
        ast,
        merge,
        help,
    }, maybeCommand.?) orelse return CLIError.InvalidCommand;

    switch (command) {
        .ast, .merge => |cmd| {
            const parsedPaths = try parsePaths(&argsIterator, allocator);

            switch (cmd) {
                .ast => {
                    result = Command{ .ast = PrintASTArgs{
                        .paths = parsedPaths,
                    } };
                },
                .merge => {
                    result = Command{ .merge = MergeArgs{
                        .paths = parsedPaths,
                    } };
                },
                else => unreachable,
            }
        },
        .help => {
            return Command{ .help = HelpArgs{} };
        },
    }

    return result;
}

fn parsePaths(args: *std.process.ArgIterator, allocator: Allocator) CLIError![][]const u8 {
    var paths: std.ArrayList([]const u8) = .empty;
    defer paths.deinit(allocator);

    while (args.next()) |path| {
        const duppedPath = allocator.dupe(u8, path) catch return CLIError.UnexpectedMemoryError;
        paths.append(allocator, duppedPath) catch return CLIError.UnexpectedMemoryError;
    }

    return paths.toOwnedSlice(allocator) catch return CLIError.UnexpectedMemoryError;
}
