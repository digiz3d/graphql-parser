const std = @import("std");
const Allocator = std.mem.Allocator;

const Document = @import("ast/document.zig").Document;
const getGqlFromExecutableDefinition = @import("printer/graphql.zig").getGqlFromExecutableDefinition;
const getDocumentText = @import("printer/text.zig").getDocumentText;

pub const Printer = struct {
    allocator: Allocator,
    document: Document,

    pub fn init(allocator: Allocator, document: Document) !Printer {
        return Printer{ .allocator = allocator, .document = document };
    }

    pub fn getGql(self: *Printer) ![]u8 {
        var graphQLString = std.ArrayList(u8).init(self.allocator);
        defer graphQLString.deinit();
        for (self.document.definitions.items) |definition| {
            try graphQLString.appendSlice(try getGqlFromExecutableDefinition(definition, self.allocator));
            try graphQLString.appendSlice("\n\n");
        }
        return graphQLString.toOwnedSlice();
    }

    pub fn getText(self: *Printer) ![]u8 {
        return getDocumentText(self.document, 0, self.allocator);
    }
};
