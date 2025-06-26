const std = @import("std");
const Allocator = std.mem.Allocator;

const Document = @import("../ast/document.zig").Document;
const FragmentDefinition = @import("../ast/fragment_definition.zig").FragmentDefinition;
const OperationDefinition = @import("../ast/operation_definition.zig").OperationDefinition;
const OperationType = @import("../ast/operation_definition.zig").OperationType;
const ExecutableDefinition = @import("../ast/executable_definition.zig").ExecutableDefinition;
const SchemaDefinition = @import("../ast/schema_definition.zig").SchemaDefinition;
const ObjectTypeDefinition = @import("../ast/object_type_definition.zig").ObjectTypeDefinition;
const UnionTypeDefinition = @import("../ast/union_type_definition.zig").UnionTypeDefinition;
const ScalarTypeDefinition = @import("../ast/scalar_type_definition.zig").ScalarTypeDefinition;
const DirectiveDefinition = @import("../ast/directive_definition.zig").DirectiveDefinition;
const InterfaceTypeDefinition = @import("../ast/interface_type_definition.zig").InterfaceTypeDefinition;
const SchemaExtension = @import("../ast/schema_extension.zig").SchemaExtension;
const ObjectTypeExtension = @import("../ast/object_type_extension.zig").ObjectTypeExtension;
const EnumTypeDefinition = @import("../ast/enum_type_definition.zig").EnumTypeDefinition;
const EnumTypeExtension = @import("../ast/enum_type_extension.zig").EnumTypeExtension;
const InputObjectTypeDefinition = @import("../ast/input_object_type_definition.zig").InputObjectTypeDefinition;
const InputObjectTypeExtension = @import("../ast/input_object_type_extension.zig").InputObjectTypeExtension;
const InterfaceTypeExtension = @import("../ast/interface_type_extension.zig").InterfaceTypeExtension;
const UnionTypeExtension = @import("../ast/union_type_extension.zig").UnionTypeExtension;
const ScalarTypeExtension = @import("../ast/scalar_type_extension.zig").ScalarTypeExtension;
const Directive = @import("../ast/directive.zig").Directive;
const SelectionSet = @import("../ast/selection_set.zig").SelectionSet;
const Selection = @import("../ast/selection.zig").Selection;
const Field = @import("../ast/field.zig").Field;
const FragmentSpread = @import("../ast/fragment_spread.zig").FragmentSpread;
const Type = @import("../ast/type.zig").Type;
const VariableDefinition = @import("../ast/variable_definition.zig").VariableDefinition;
const OperationTypeDefinition = @import("../ast/operation_type_definition.zig").OperationTypeDefinition;
const Interface = @import("../ast/interface.zig").Interface;
const FieldDefinition = @import("../ast/field_definition.zig").FieldDefinition;
const InputValueDefinition = @import("../ast/input_value_definition.zig").InputValueDefinition;
const EnumValueDefinition = @import("../ast/enum_value_definition.zig").EnumValueDefinition;
const Argument = @import("../ast/arguments.zig").Argument;
const InlineFragment = @import("../ast/inline_fragment.zig").InlineFragment;
const NamedType = @import("../ast/type.zig").NamedType;
const ListType = @import("../ast/type.zig").ListType;
const NonNullType = @import("../ast/type.zig").NonNullType;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;

pub fn getDocumentText(document: Document, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- Document\n", .{spaces});
    try w.print("{s}  definitions: {d}\n", .{ spaces, document.definitions.items.len });
    for (document.definitions.items) |item| {
        try w.print("{s}", .{try getExecutableDefinitionText(item, indent + 1, allocator)});
    }
    return text.toOwnedSlice();
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

fn getFragmentDefinitionText(def: FragmentDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- FragmentDefinition\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        try w.print("{s}", .{try getDirectiveText(item, indent + 1, allocator)});
    }
    try w.print("{s}  selectionSet: \n", .{spaces});
    try w.print("{s}", .{try getSelectionSetText(def.selectionSet, indent + 1, allocator)});
    try w.print("{s}  typeCondition: \n", .{spaces});
    try w.print("{s}", .{try getTypeText(def.typeCondition, indent + 1, allocator)});

    return text.toOwnedSlice();
}

fn getOperationDefinitionText(def: OperationDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- OperationDefinition\n", .{spaces});
    try w.print("{s}  operation = {s}\n", .{ spaces, switch (def.operation) {
        OperationType.query => "query",
        OperationType.mutation => "mutation",
        OperationType.subscription => "subscription",
    } });
    try w.print("{s}  name = {?s}\n", .{ spaces, def.name });
    try w.print("{s}  variableDefinitions: {d}\n", .{ spaces, def.variableDefinitions.len });
    for (def.variableDefinitions) |item| {
        try w.print("{s}", .{try getVariableDefinitionText(item, indent + 1, allocator)});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        try w.print("{s}", .{try getDirectiveText(item, indent + 1, allocator)});
    }
    try w.print("{s}  selectionSet: \n", .{spaces});
    try w.print("{s}", .{try getSelectionSetText(def.selectionSet, indent + 1, allocator)});

    return text.toOwnedSlice();
}

fn getSchemaDefinitionText(def: SchemaDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- SchemaDefinition\n", .{spaces});
    if (def.description != null) {
        const newDescription = newLineToBackslashN(allocator, def.description.?);
        defer allocator.free(newDescription);
        try w.print("{s}  description = \"{s}\"\n", .{ spaces, newDescription });
    } else {
        try w.print("{s}  description = null\n", .{spaces});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        try w.print("{s}", .{try getDirectiveText(item, indent + 1, allocator)});
    }
    try w.print("{s}  operationTypes: {d}\n", .{ spaces, def.operationTypes.len });
    for (def.operationTypes) |item| {
        try w.print("{s}", .{try getOperationTypeDefinitionText(item, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getObjectTypeDefinitionText(def: ObjectTypeDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- ObjectTypeDefinition\n", .{spaces});
    if (def.description != null) {
        const str = newLineToBackslashN(allocator, def.description.?);
        defer allocator.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  interfaces: {d}\n", .{ spaces, def.interfaces.len });
    for (def.interfaces) |interface| {
        try w.print("{s}", .{try getInterfaceText(interface, indent + 1, allocator)});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        try w.print("{s}", .{try getDirectiveText(item, indent + 1, allocator)});
    }
    try w.print("{s}  fields: {d}\n", .{ spaces, def.fields.len });
    for (def.fields) |item| {
        try w.print("{s}", .{try getFieldDefinitionText(item, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getUnionTypeDefinitionText(def: UnionTypeDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- UnionTypeDefinition\n", .{spaces});
    if (def.description != null) {
        const str = newLineToBackslashN(allocator, def.description.?);
        defer allocator.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });
    try w.print("{s}  types:\n", .{spaces});
    for (def.types) |t| {
        try w.print("{s}", .{try getTypeText(t, indent + 1, allocator)});
    }
    try w.print("{s}  directives:\n", .{spaces});
    for (def.directives) |directive| {
        try w.print("{s}", .{try getDirectiveText(directive, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getScalarTypeDefinitionText(def: ScalarTypeDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- ScalarTypeDefinition\n", .{spaces});
    if (def.description != null) {
        const str = newLineToBackslashN(allocator, def.description.?);
        defer allocator.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives:\n", .{spaces});
    for (def.directives) |directive| {
        try w.print("{s}", .{try getDirectiveText(directive, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getDirectiveDefinitionText(def: DirectiveDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- DirectiveDefinition\n", .{spaces});
    if (def.description != null) {
        const str = newLineToBackslashN(allocator, def.description.?);
        defer allocator.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });
    try w.print("{s}  arguments: {d}\n", .{ spaces, def.arguments.len });
    for (def.arguments) |arg| {
        try w.print("{s}", .{try getInputValueDefinitionText(arg, indent + 1, allocator)});
    }
    try w.print("{s}  locations: {d}\n", .{ spaces, def.locations.len });
    for (def.locations) |location| {
        try w.print("{s}    - {s}\n", .{ spaces, location });
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        try w.print("{s}", .{try getDirectiveText(directive, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getInterfaceTypeDefinitionText(def: InterfaceTypeDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- InterfaceTypeDefinition\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  description = {?s}\n", .{ spaces, def.description });
    try w.print("{s}  interfaces: {d}\n", .{ spaces, def.interfaces.len });
    for (def.interfaces) |interface| {
        try w.print("{s}", .{try getInterfaceText(interface, indent + 1, allocator)});
    }
    try w.print("{s}  fields: {d}\n", .{ spaces, def.fields.len });
    for (def.fields) |field| {
        try w.print("{s}", .{try getFieldDefinitionText(field, indent + 1, allocator)});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        try w.print("{s}", .{try getDirectiveText(directive, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getSchemaExtensionText(def: SchemaExtension, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- SchemaExtension\n", .{spaces});
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        try w.print("{s}", .{try getDirectiveText(directive, indent + 1, allocator)});
    }
    try w.print("{s}  operationTypes: {d}\n", .{ spaces, def.operationTypes.len });
    for (def.operationTypes) |operationType| {
        try w.print("{s}", .{try getOperationTypeDefinitionText(operationType, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getObjectTypeExtensionText(def: ObjectTypeExtension, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- ObjectTypeExtension\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  interfaces: {d}\n", .{ spaces, def.interfaces.len });
    for (def.interfaces) |interface| {
        try w.print("{s}", .{try getInterfaceText(interface, indent + 1, allocator)});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        try w.print("{s}", .{try getDirectiveText(directive, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getEnumTypeDefinitionText(def: EnumTypeDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- EnumTypeDefinition\n", .{spaces});
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });
    if (def.description != null) {
        const str = newLineToBackslashN(allocator, def.description.?);
        defer allocator.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        try w.print("{s}", .{try getDirectiveText(directive, indent + 1, allocator)});
    }
    try w.print("{s}  values: {d}\n", .{ spaces, def.values.len });
    for (def.values) |value| {
        try w.print("{s}", .{try getEnumValueDefinitionText(value, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getEnumTypeExtensionText(def: EnumTypeExtension, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- EnumTypeExtension\n", .{spaces});
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        try w.print("{s}", .{try getDirectiveText(directive, indent + 1, allocator)});
    }
    try w.print("{s}  values: {d}\n", .{ spaces, def.values.len });
    for (def.values) |value| {
        try w.print("{s}", .{try getEnumValueDefinitionText(value, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getInputObjectTypeDefinitionText(def: InputObjectTypeDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- InputObjectTypeDefinition\n", .{spaces});
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });
    if (def.description != null) {
        const str = newLineToBackslashN(allocator, def.description.?);
        defer allocator.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        try w.print("{s}", .{try getDirectiveText(directive, indent + 1, allocator)});
    }
    try w.print("{s}  fields: {d}\n", .{ spaces, def.fields.len });
    for (def.fields) |field| {
        try w.print("{s}", .{try getInputValueDefinitionText(field, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getInputObjectTypeExtensionText(def: InputObjectTypeExtension, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- InputObjectTypeExtension\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        try w.print("{s}", .{try getDirectiveText(directive, indent + 1, allocator)});
    }
    try w.print("{s}  fields: {d}\n", .{ spaces, def.fields.len });
    for (def.fields) |field| {
        try w.print("{s}", .{try getInputValueDefinitionText(field, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getInterfaceTypeExtensionText(def: InterfaceTypeExtension, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- InterfaceTypeExtension\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  interfaces: {d}\n", .{ spaces, def.interfaces.len });
    for (def.interfaces) |interface| {
        try w.print("{s}", .{try getInterfaceText(interface, indent + 1, allocator)});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        try w.print("{s}", .{try getDirectiveText(directive, indent + 1, allocator)});
    }
    try w.print("{s}  fields: {d}\n", .{ spaces, def.fields.len });
    for (def.fields) |field| {
        try w.print("{s}", .{try getFieldDefinitionText(field, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getUnionTypeExtensionText(def: UnionTypeExtension, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- UnionTypeExtension\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        try w.print("{s}", .{try getDirectiveText(directive, indent + 1, allocator)});
    }
    try w.print("{s}  types: {d}\n", .{ spaces, def.types.len });
    for (def.types) |t| {
        try w.print("{s}", .{try getTypeText(t, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getScalarTypeExtensionText(def: ScalarTypeExtension, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- ScalarTypeExtension\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        try w.print("{s}", .{try getDirectiveText(directive, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getDirectiveText(def: Directive, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- Directive\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  arguments: {d}\n", .{ spaces, def.arguments.len });
    for (def.arguments) |item| {
        try w.print("{s}", .{try getArgumentText(item, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getSelectionSetText(def: SelectionSet, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- SelectionSet\n", .{spaces});
    try w.print("{s}  selections:\n", .{spaces});
    for (def.selections) |item| {
        try w.print("{s}", .{try getSelectionText(item, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getSelectionText(def: Selection, indent: usize, allocator: Allocator) anyerror![]u8 {
    return switch (def) {
        .field => |field| getFieldText(field, indent, allocator),
        .fragmentSpread => |fragmentSpread| getFragmentSpreadText(fragmentSpread, indent, allocator),
        .inlineFragment => |inlineFragment| getInlineFragmentText(inlineFragment, indent, allocator),
    };
}

fn getFieldText(def: Field, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- FieldData\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    if (def.alias != null) {
        try w.print("{s}  alias = {?s}\n", .{ spaces, if (def.alias.?.len > 0) def.alias else "none" });
    } else {
        try w.print("{s}  alias = null\n", .{spaces});
    }
    try w.print("{s}  arguments: {d}\n", .{ spaces, def.arguments.len });
    for (def.arguments) |item| {
        try w.print("{s}", .{try getArgumentText(item, indent + 1, allocator)});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        try w.print("{s}", .{try getDirectiveText(item, indent + 1, allocator)});
    }
    if (def.selectionSet != null) {
        try w.print("{s}  selectionSet: \n", .{spaces});
        if (def.selectionSet) |set| {
            try w.print("{s}", .{try getSelectionSetText(set, indent + 1, allocator)});
        }
    } else {
        try w.print("{s}  selectionSet: null\n", .{spaces});
    }

    return text.toOwnedSlice();
}

fn getFragmentSpreadText(def: FragmentSpread, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- FragmentSpread\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        try w.print("{s}", .{try getDirectiveText(item, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getTypeText(def: Type, indent: usize, allocator: Allocator) anyerror![]u8 {
    return switch (def) {
        .namedType => |n| getNamedTypeText(n, indent, allocator),
        .listType => |n| getListTypeText(n, indent, allocator),
        .nonNullType => |n| getNonNullTypeText(n, indent, allocator),
    };
}

fn getVariableDefinitionText(def: VariableDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- VariableDefinition\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    try w.print("{s}  type\n", .{spaces});
    try w.print("{s}", .{try getTypeText(def.type, indent, allocator)});
    if (def.defaultValue != null) {
        const value = def.defaultValue.?.getPrintableString(allocator);
        defer allocator.free(value);
        try w.print("{s}  defaultValue = {s}\n", .{ spaces, value });
    } else {
        try w.print("{s}  defaultValue = null\n", .{spaces});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        try w.print("{s}", .{try getDirectiveText(item, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getOperationTypeDefinitionText(def: OperationTypeDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- OperationTypeDefinition\n", .{spaces});
    try w.print("{s}  operation: {s}\n", .{ spaces, def.operation });
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });

    return text.toOwnedSlice();
}

fn getInterfaceText(def: Interface, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- {s}\n", .{ spaces, def.type.getPrintableString(allocator) });

    return text.toOwnedSlice();
}

fn getFieldDefinitionText(def: FieldDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- FieldDefinition\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    if (def.description != null) {
        const str = newLineToBackslashN(allocator, def.description.?);
        defer allocator.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  arguments: {d}\n", .{ spaces, def.arguments.len });
    for (def.arguments) |item| {
        try w.print("{s}", .{try getInputValueDefinitionText(item, indent + 1, allocator)});
    }
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        try w.print("{s}", .{try getDirectiveText(item, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getInputValueDefinitionText(def: InputValueDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- InputValueDefinition\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    if (def.description != null) {
        const str = newLineToBackslashN(allocator, def.description.?);
        defer allocator.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    const value = def.value.getPrintableString(allocator);
    defer allocator.free(value);
    try w.print("{s}  value = {s}\n", .{ spaces, value });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        try w.print("{s}", .{try getDirectiveText(item, indent + 1, allocator)});
    }
    if (def.defaultValue != null) {
        const value2 = def.defaultValue.?.getPrintableString(allocator);
        defer allocator.free(value2);
        try w.print("{s}  defaultValue: {s}\n", .{ spaces, value2 });
    } else {
        try w.print("{s}  defaultValue: null\n", .{spaces});
    }

    return text.toOwnedSlice();
}

fn getEnumValueDefinitionText(def: EnumValueDefinition, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- EnumValueDefinition\n", .{spaces});
    if (def.description != null) {
        const str = newLineToBackslashN(allocator, def.description.?);
        defer allocator.free(str);
        try w.print("{s}  description: {s}\n", .{ spaces, str });
    } else {
        try w.print("{s}  description: null\n", .{spaces});
    }
    try w.print("{s}  name: {s}\n", .{ spaces, def.name });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |directive| {
        try w.print("{s}", .{try getDirectiveText(directive, indent + 1, allocator)});
    }

    return text.toOwnedSlice();
}

fn getArgumentText(def: Argument, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- Argument\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });
    const value = def.value.getPrintableString(allocator);
    defer allocator.free(value);
    try w.print("{s}  value = {s}\n", .{ spaces, value });

    return text.toOwnedSlice();
}

fn getInlineFragmentText(def: InlineFragment, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- InlineFragment\n", .{spaces});
    try w.print("{s}  typeCondition = {s}\n", .{ spaces, def.typeCondition });
    try w.print("{s}  directives: {d}\n", .{ spaces, def.directives.len });
    for (def.directives) |item| {
        try w.print("{s}", .{try getDirectiveText(item, indent + 1, allocator)});
    }
    try w.print("{s}  selectionSet: \n", .{spaces});
    try w.print("{s}", .{try getSelectionSetText(def.selectionSet, indent + 1, allocator)});

    return text.toOwnedSlice();
}

fn getNamedTypeText(def: NamedType, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- NamedType\n", .{spaces});
    try w.print("{s}  name = {s}\n", .{ spaces, def.name });

    return text.toOwnedSlice();
}

fn getListTypeText(def: ListType, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- ListType\n", .{spaces});
    try w.print("{s}  type\n", .{spaces});
    try w.print("{s}", .{try getTypeText(def.elementType.*, indent + 1, allocator)});

    return text.toOwnedSlice();
}

fn getNonNullTypeText(def: NonNullType, indent: usize, allocator: Allocator) ![]u8 {
    const spaces = makeIndentation(indent, allocator);
    defer allocator.free(spaces);
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();

    try w.print("{s}- NonNullType\n", .{spaces});
    try w.print("{s}  type\n", .{spaces});
    switch (def) {
        .namedType => |n| try w.print("{s}", .{try getNamedTypeText(n, indent + 1, allocator)}),
        .listType => |n| try w.print("{s}", .{try getListTypeText(n, indent + 1, allocator)}),
    }

    return text.toOwnedSlice();
}
