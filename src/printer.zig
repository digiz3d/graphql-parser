const std = @import("std");
const Allocator = std.mem.Allocator;

const Document = @import("ast/document.zig").Document;
const getGqlFromExecutableDefinition = @import("printer/graphql.zig").getGqlFromExecutableDefinition;
const getDocumentText = @import("printer/text.zig").getDocumentText;

pub const Printer = struct {
    allocator: Allocator,
    document: Document,
    currentIndent: usize,
    buffer: std.ArrayList(u8),

    pub fn init(allocator: Allocator, document: Document) !Printer {
        return Printer{
            .allocator = allocator,
            .document = document,
            .currentIndent = 0,
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn getGql(self: *Printer) ![]u8 {
        for (self.document.definitions.items, 0..) |definition, i| {
            try getGqlFromExecutableDefinition(self, definition);
            if (i < self.document.definitions.items.len - 1) {
                try self.append("\n\n");
            }
        }
        try self.appendByte('\n');
        return self.buffer.toOwnedSlice();
    }

    pub fn getText(self: *Printer) ![]u8 {
        return getDocumentText(self.document, 0, self.allocator);
    }

    pub fn append(self: *Printer, str: []const u8) !void {
        try self.buffer.appendSlice(str);
    }

    pub fn appendByte(self: *Printer, byte: u8) !void {
        try self.buffer.append(byte);
    }

    pub fn newLine(self: *Printer) !void {
        try self.appendByte('\n');
        for (0..self.currentIndent) |_| {
            try self.appendByte(' ');
        }
    }

    pub fn openBrace(self: *Printer) !void {
        try self.append(" {");
        self.indent();
    }

    pub fn closeBrace(self: *Printer) !void {
        self.unindent();
        try self.newLine();
        try self.appendByte('}');
    }

    fn indent(self: *Printer) void {
        self.currentIndent += 2;
    }

    fn unindent(self: *Printer) void {
        self.currentIndent -= 2;
    }
};
