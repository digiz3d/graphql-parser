const std = @import("std");
const Allocator = std.mem.Allocator;

const Printer = @import("../print.zig").Printer;
const Argument = @import("../ast/arguments.zig").Argument;
const Directive = @import("../ast/directive.zig").Directive;
const DirectiveDefinition = @import("../ast/directive_definition.zig").DirectiveDefinition;
const EnumTypeDefinition = @import("../ast/enum_type_definition.zig").EnumTypeDefinition;
const EnumTypeExtension = @import("../ast/enum_type_extension.zig").EnumTypeExtension;
const EnumValueDefinition = @import("../ast/enum_value_definition.zig").EnumValueDefinition;
const ExecutableDefinition = @import("../ast/executable_definition.zig").ExecutableDefinition;
const Field = @import("../ast/field.zig").Field;
const FieldDefinition = @import("../ast/field_definition.zig").FieldDefinition;
const FragmentDefinition = @import("../ast/fragment_definition.zig").FragmentDefinition;
const FragmentSpread = @import("../ast/fragment_spread.zig").FragmentSpread;
const InlineFragment = @import("../ast/inline_fragment.zig").InlineFragment;
const InputObjectTypeDefinition = @import("../ast/input_object_type_definition.zig").InputObjectTypeDefinition;
const InputObjectTypeExtension = @import("../ast/input_object_type_extension.zig").InputObjectTypeExtension;
const InputValueDefinition = @import("../ast/input_value_definition.zig").InputValueDefinition;
const Interface = @import("../ast/interface.zig").Interface;
const InterfaceTypeDefinition = @import("../ast/interface_type_definition.zig").InterfaceTypeDefinition;
const InterfaceTypeExtension = @import("../ast/interface_type_extension.zig").InterfaceTypeExtension;
const ListType = @import("../ast/type.zig").ListType;
const NamedType = @import("../ast/type.zig").NamedType;
const NonNullType = @import("../ast/type.zig").NonNullType;
const ObjectTypeDefinition = @import("../ast/object_type_definition.zig").ObjectTypeDefinition;
const ObjectTypeExtension = @import("../ast/object_type_extension.zig").ObjectTypeExtension;
const OperationDefinition = @import("../ast/operation_definition.zig").OperationDefinition;
const OperationType = @import("../ast/operation_definition.zig").OperationType;
const OperationTypeDefinition = @import("../ast/operation_type_definition.zig").OperationTypeDefinition;
const ScalarTypeDefinition = @import("../ast/scalar_type_definition.zig").ScalarTypeDefinition;
const ScalarTypeExtension = @import("../ast/scalar_type_extension.zig").ScalarTypeExtension;
const SchemaDefinition = @import("../ast/schema_definition.zig").SchemaDefinition;
const SchemaExtension = @import("../ast/schema_extension.zig").SchemaExtension;
const Selection = @import("../ast/selection.zig").Selection;
const SelectionSet = @import("../ast/selection_set.zig").SelectionSet;
const Type = @import("../ast/type.zig").Type;
const UnionTypeDefinition = @import("../ast/union_type_definition.zig").UnionTypeDefinition;
const UnionTypeExtension = @import("../ast/union_type_extension.zig").UnionTypeExtension;
const VariableDefinition = @import("../ast/variable_definition.zig").VariableDefinition;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;

pub fn getDocumentText(printer: *Printer) !void {
    const spaces = makeIndentation(0, printer.allocator);
    defer printer.allocator.free(spaces);
    const w = printer.buffer.writer(printer.allocator);

    try w.print("{s}- Document\n", .{spaces});
    try w.print("{s}  definitions: {d}\n", .{ spaces, printer.document.definitions.len });
    for (printer.document.definitions) |item| {
        const txt = try getExecutableDefinitionText(item, 1, printer.allocator);
        defer printer.allocator.free(txt);
        try w.print("{s}", .{txt});
    }
}

fn getExecutableDefinitionText(executableDefinition: ExecutableDefinition, indent: usize, allocator: Allocator) ![]u8 {
    return switch (executableDefinition) {
        .fragmentDefinition => |def| getFragmentDefinitionText(def, indent, allocator),
        .operationDefinition => |def| getOperationDefinitionText(def, indent, allocator),
        .schemaDefinition => |def| getSchemaDefinitionText(def, indent, allocator),
        .objectTypeDefinition => |def| getObjectTypeDefinitionText(def, indent, allocator),
        .unionTypeDefinition => |def| getUnionTypeDefinitionText(def, indent, allocator),
        .scalarTypeDefinition => |def| getScalarTypeDefinitionText(def, indent, allocator),
        .directiveDefinition => |def| getDirectiveDefinitionText(def, indent, allocator),
        .interfaceTypeDefinition => |def| getInterfaceTypeDefinitionText(def, indent, allocator),
        .schemaExtension => |def| getSchemaExtensionText(def, indent, allocator),
        .objectTypeExtension => |def| getObjectTypeExtensionText(def, indent, allocator),
        .enumTypeDefinition => |def| getEnumTypeDefinitionText(def, indent, allocator),
        .enumTypeExtension => |def| getEnumTypeExtensionText(def, indent, allocator),
        .inputObjectTypeDefinition => |def| getInputObjectTypeDefinitionText(def, indent, allocator),
        .inputObjectTypeExtension => |def| getInputObjectTypeExtensionText(def, indent, allocator),
        .interfaceTypeExtension => |def| getInterfaceTypeExtensionText(def, indent, allocator),
        .unionTypeExtension => |def| getUnionTypeExtensionText(def, indent, allocator),
        .scalarTypeExtension => |def| getScalarTypeExtensionText(def, indent, allocator),
    };
}

fn getFragmentDefinitionText(def: FragmentDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- FragmentDefinition\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        const txt = try getDirectiveText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  selectionSet:\n", .{spaces});
    const selectionSetTxt = try getSelectionSetText(def.selectionSet, indent + 1, gpa);
    defer gpa.free(selectionSetTxt);
    try w.print("{s}", .{selectionSetTxt});
    try w.print("{s}  typeCondition:\n", .{spaces});
    const typeConditionTxt = try getTypeText(def.typeCondition, indent + 1, gpa);
    defer gpa.free(typeConditionTxt);
    try w.print("{s}", .{typeConditionTxt});

    return text.toOwnedSlice(gpa);
}

fn getOperationDefinitionText(def: OperationDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- OperationDefinition\n", .{spaces});
    try w.print("{s}  operation = {s}\n", .{ spaces, switch (def.operation) {
        OperationType.query => "query",
        OperationType.mutation => "mutation",
        OperationType.subscription => "subscription",
    } });
    try w.print("{s}  name = {?s}\n", .{ spaces, def.name });
    try w.print("{s}  variableDefinitions: {d}\n", .{ spaces, def.variableDefinitions.len });
    for (def.variableDefinitions) |item| {
        const txt = try getVariableDefinitionText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        const txt = try getDirectiveText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  selectionSet:\n", .{spaces});
    const selectionSetTxt = try getSelectionSetText(def.selectionSet, indent + 1, gpa);
    defer gpa.free(selectionSetTxt);
    try w.print("{s}", .{selectionSetTxt});

    return text.toOwnedSlice(gpa);
}

fn getSchemaDefinitionText(def: SchemaDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- SchemaDefinition\n", .{spaces});
    if (def.description != null) {
        const newDescription = newLineToBackslashN(gpa, def.description.?);
        defer gpa.free(newDescription);
        try w.print("{s}  description = \"{s}\"\n", .{ spaces, newDescription });
    } else {
        try w.print("{s}  description = null\n", .{spaces});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        const txt = try getDirectiveText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  operationTypes: {d}\n", .{ spaces, def.operationTypes.len });
    for (def.operationTypes) |item| {
        const txt = try getOperationTypeDefinitionText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getObjectTypeDefinitionText(def: ObjectTypeDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- ObjectTypeDefinition\n", .{spaces});
    if (def.description != null) {
        const str = newLineToBackslashN(gpa, def.description.?);
        defer gpa.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  interfaces: {d}\n", .{ spaces, def.interfaces.len });
    for (def.interfaces) |interface| {
        const txt = try getInterfaceText(interface, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        const txt = try getDirectiveText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  fields: {d}\n", .{ spaces, def.fields.len });
    for (def.fields) |item| {
        const txt = try getFieldDefinitionText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getUnionTypeDefinitionText(def: UnionTypeDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- UnionTypeDefinition\n", .{spaces});
    if (def.description != null) {
        const str = newLineToBackslashN(gpa, def.description.?);
        defer gpa.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });
    try w.print("{s}  types:\n", .{spaces});
    for (def.types) |t| {
        const txt = try getTypeText(t, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  directives:\n", .{spaces});
    for (def.directives) |directive| {
        const txt = try getDirectiveText(directive, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getScalarTypeDefinitionText(def: ScalarTypeDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- ScalarTypeDefinition\n", .{spaces});
    if (def.description != null) {
        const str = newLineToBackslashN(gpa, def.description.?);
        defer gpa.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives:\n", .{spaces});
    for (def.directives) |directive| {
        const txt = try getDirectiveText(directive, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getDirectiveDefinitionText(def: DirectiveDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- DirectiveDefinition\n", .{spaces});
    if (def.description != null) {
        const str = newLineToBackslashN(gpa, def.description.?);
        defer gpa.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });
    try w.print("{s}  arguments: {d}\n", .{ spaces, def.arguments.len });
    for (def.arguments) |arg| {
        const txt = try getInputValueDefinitionText(arg, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  locations: {d}\n", .{ spaces, def.locations.len });
    for (def.locations) |location| {
        try w.print("{s}    - {s}\n", .{ spaces, location });
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        const txt = try getDirectiveText(directive, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getInterfaceTypeDefinitionText(def: InterfaceTypeDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- InterfaceTypeDefinition\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  description = {?s}\n", .{ spaces, def.description });
    try w.print("{s}  interfaces: {d}\n", .{ spaces, def.interfaces.len });
    for (def.interfaces) |interface| {
        const txt = try getInterfaceText(interface, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  fields: {d}\n", .{ spaces, def.fields.len });
    for (def.fields) |field| {
        const txt = try getFieldDefinitionText(field, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        const txt = try getDirectiveText(directive, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getSchemaExtensionText(def: SchemaExtension, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- SchemaExtension\n", .{spaces});
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        const txt = try getDirectiveText(directive, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  operationTypes: {d}\n", .{ spaces, def.operationTypes.len });
    for (def.operationTypes) |operationType| {
        const txt = try getOperationTypeDefinitionText(operationType, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getObjectTypeExtensionText(def: ObjectTypeExtension, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- ObjectTypeExtension\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  interfaces: {d}\n", .{ spaces, def.interfaces.len });
    for (def.interfaces) |interface| {
        const txt = try getInterfaceText(interface, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        const txt = try getDirectiveText(directive, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getEnumTypeDefinitionText(def: EnumTypeDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- EnumTypeDefinition\n", .{spaces});
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });
    if (def.description != null) {
        const str = newLineToBackslashN(gpa, def.description.?);
        defer gpa.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        const txt = try getDirectiveText(directive, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  values: {d}\n", .{ spaces, def.values.len });
    for (def.values) |value| {
        const txt = try getEnumValueDefinitionText(value, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getEnumTypeExtensionText(def: EnumTypeExtension, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- EnumTypeExtension\n", .{spaces});
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        const txt = try getDirectiveText(directive, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  values: {d}\n", .{ spaces, def.values.len });
    for (def.values) |value| {
        const txt = try getEnumValueDefinitionText(value, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getInputObjectTypeDefinitionText(def: InputObjectTypeDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- InputObjectTypeDefinition\n", .{spaces});
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });
    if (def.description != null) {
        const str = newLineToBackslashN(gpa, def.description.?);
        defer gpa.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        const txt = try getDirectiveText(directive, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  fields: {d}\n", .{ spaces, def.fields.len });
    for (def.fields) |field| {
        const txt = try getInputValueDefinitionText(field, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getInputObjectTypeExtensionText(def: InputObjectTypeExtension, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- InputObjectTypeExtension\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        const txt = try getDirectiveText(directive, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  fields: {d}\n", .{ spaces, def.fields.len });
    for (def.fields) |field| {
        const txt = try getInputValueDefinitionText(field, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getInterfaceTypeExtensionText(def: InterfaceTypeExtension, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- InterfaceTypeExtension\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  interfaces: {d}\n", .{ spaces, def.interfaces.len });
    for (def.interfaces) |interface| {
        const txt = try getInterfaceText(interface, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        const txt = try getDirectiveText(directive, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  fields: {d}\n", .{ spaces, def.fields.len });
    for (def.fields) |field| {
        const txt = try getFieldDefinitionText(field, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getUnionTypeExtensionText(def: UnionTypeExtension, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- UnionTypeExtension\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        const txt = try getDirectiveText(directive, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  types: {d}\n", .{ spaces, def.types.len });
    for (def.types) |t| {
        const txt = try getTypeText(t, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getScalarTypeExtensionText(def: ScalarTypeExtension, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- ScalarTypeExtension\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        const txt = try getDirectiveText(directive, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getDirectiveText(def: Directive, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- Directive\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  arguments: {d}\n", .{ spaces, def.arguments.len });
    for (def.arguments) |item| {
        const txt = try getArgumentText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getSelectionSetText(def: SelectionSet, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- SelectionSet\n", .{spaces});
    try w.print("{s}  selections:\n", .{spaces});
    for (def.selections) |item| {
        const txt = try getSelectionText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getSelectionText(def: Selection, indent: usize, gpa: Allocator) anyerror![]u8 {
    return switch (def) {
        .field => |field| getFieldText(field, indent, gpa),
        .fragmentSpread => |fragmentSpread| getFragmentSpreadText(fragmentSpread, indent, gpa),
        .inlineFragment => |inlineFragment| getInlineFragmentText(inlineFragment, indent, gpa),
    };
}

fn getFieldText(def: Field, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- FieldData\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    if (def.alias != null) {
        try w.print("{s}  alias = {?s}\n", .{ spaces, if (def.alias.?.len > 0) def.alias else "none" });
    } else {
        try w.print("{s}  alias = null\n", .{spaces});
    }
    try w.print("{s}  arguments: {d}\n", .{ spaces, def.arguments.len });
    for (def.arguments) |item| {
        const txt = try getArgumentText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        const txt = try getDirectiveText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    if (def.selectionSet != null) {
        try w.print("{s}  selectionSet:\n", .{spaces});
        if (def.selectionSet) |set| {
            const txt = try getSelectionSetText(set, indent + 1, gpa);
            defer gpa.free(txt);
            try w.print("{s}", .{txt});
        }
    } else {
        try w.print("{s}  selectionSet: null\n", .{spaces});
    }

    return text.toOwnedSlice(gpa);
}

fn getFragmentSpreadText(def: FragmentSpread, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- FragmentSpread\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        const txt = try getDirectiveText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getTypeText(def: Type, indent: usize, gpa: Allocator) anyerror![]u8 {
    return switch (def) {
        .namedType => |n| getNamedTypeText(n, indent, gpa),
        .listType => |n| getListTypeText(n, indent, gpa),
        .nonNullType => |n| getNonNullTypeText(n, indent, gpa),
    };
}

fn getVariableDefinitionText(def: VariableDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- VariableDefinition\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  type\n", .{spaces});
    {
        const txt = try getTypeText(def.type, indent, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    if (def.defaultValue != null) {
        const value = def.defaultValue.?.getPrintableString(gpa);
        defer gpa.free(value);
        try w.print("{s}  defaultValue = {s}\n", .{ spaces, value });
    } else {
        try w.print("{s}  defaultValue = null\n", .{spaces});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        const txt = try getDirectiveText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getOperationTypeDefinitionText(def: OperationTypeDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- OperationTypeDefinition\n", .{spaces});
    try w.print("{s}  operation: {s}\n", .{ spaces, def.operation });
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });

    return text.toOwnedSlice(gpa);
}

fn getInterfaceText(def: Interface, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    const printableString = def.type.getPrintableString(gpa);
    defer gpa.free(printableString);
    try w.print("{s}- {s}\n", .{ spaces, printableString });

    return text.toOwnedSlice(gpa);
}

fn getFieldDefinitionText(def: FieldDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- FieldDefinition\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    if (def.description != null) {
        const str = newLineToBackslashN(gpa, def.description.?);
        defer gpa.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  arguments: {d}\n", .{ spaces, def.arguments.len });
    for (def.arguments) |item| {
        const txt = try getInputValueDefinitionText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        const txt = try getDirectiveText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getInputValueDefinitionText(def: InputValueDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- InputValueDefinition\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    if (def.description != null) {
        const str = newLineToBackslashN(gpa, def.description.?);
        defer gpa.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    const value = def.value.getPrintableString(gpa);
    defer gpa.free(value);
    try w.print("{s}  value = {s}\n", .{ spaces, value });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        const txt = try getDirectiveText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    if (def.defaultValue != null) {
        const value2 = def.defaultValue.?.getPrintableString(gpa);
        defer gpa.free(value2);
        try w.print("{s}  defaultValue: {s}\n", .{ spaces, value2 });
    } else {
        try w.print("{s}  defaultValue: null\n", .{spaces});
    }

    return text.toOwnedSlice(gpa);
}

fn getEnumValueDefinitionText(def: EnumValueDefinition, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- EnumValueDefinition\n", .{spaces});
    if (def.description != null) {
        const str = newLineToBackslashN(gpa, def.description.?);
        defer gpa.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        const txt = try getDirectiveText(directive, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getArgumentText(def: Argument, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- Argument\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    const value = def.value.getPrintableString(gpa);
    defer gpa.free(value);
    try w.print("{s}  value = {s}\n", .{ spaces, value });

    return text.toOwnedSlice(gpa);
}

fn getInlineFragmentText(def: InlineFragment, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- InlineFragment\n", .{spaces});
    try w.print("{s}  typeCondition = {s}\n", .{ spaces, def.typeCondition });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        const txt = try getDirectiveText(item, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }
    try w.print("{s}  selectionSet:\n", .{spaces});
    const txt = try getSelectionSetText(def.selectionSet, indent + 1, gpa);
    defer gpa.free(txt);
    try w.print("{s}", .{txt});

    return text.toOwnedSlice(gpa);
}

fn getNamedTypeText(def: NamedType, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- NamedType\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });

    return text.toOwnedSlice(gpa);
}

fn getListTypeText(def: ListType, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- ListType\n", .{spaces});
    try w.print("{s}  type\n", .{spaces});
    {
        const txt = try getTypeText(def.elementType.*, indent + 1, gpa);
        defer gpa.free(txt);
        try w.print("{s}", .{txt});
    }

    return text.toOwnedSlice(gpa);
}

fn getNonNullTypeText(def: NonNullType, indent: usize, gpa: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, gpa);
    defer gpa.free(spaces);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(gpa);
    const w = text.writer(gpa);

    try w.print("{s}- NonNullType\n", .{spaces});
    try w.print("{s}  type\n", .{spaces});
    switch (def) {
        .namedType => |n| {
            const txt = try getNamedTypeText(n, indent + 1, gpa);
            defer gpa.free(txt);
            try w.print("{s}", .{txt});
        },
        .listType => |n| {
            const txt = try getListTypeText(n, indent + 1, gpa);
            defer gpa.free(txt);
            try w.print("{s}", .{txt});
        },
    }

    return text.toOwnedSlice(gpa);
}
