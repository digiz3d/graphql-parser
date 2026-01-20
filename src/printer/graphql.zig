const std = @import("std");

const Printer = @import("../printer.zig").Printer;
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
const InputObjectTypeDefinition = @import("../ast/input_object_type_definition.zig").InputObjectTypeDefinition;
const InputObjectTypeExtension = @import("../ast/input_object_type_extension.zig").InputObjectTypeExtension;
const InputValue = @import("../ast/input_value.zig").InputValue;
const InputValueDefinition = @import("../ast/input_value_definition.zig").InputValueDefinition;
const Interface = @import("../ast/interface.zig").Interface;
const InterfaceTypeDefinition = @import("../ast/interface_type_definition.zig").InterfaceTypeDefinition;
const InterfaceTypeExtension = @import("../ast/interface_type_extension.zig").InterfaceTypeExtension;
const ObjectTypeDefinition = @import("../ast/object_type_definition.zig").ObjectTypeDefinition;
const ObjectTypeExtension = @import("../ast/object_type_extension.zig").ObjectTypeExtension;
const OperationDefinition = @import("../ast/operation_definition.zig").OperationDefinition;
const OperationType = @import("../ast/operation_definition.zig").OperationType;
const OperationTypeDefinition = @import("../ast/operation_type_definition.zig").OperationTypeDefinition;
const ScalarTypeDefinition = @import("../ast/scalar_type_definition.zig").ScalarTypeDefinition;
const ScalarTypeExtension = @import("../ast/scalar_type_extension.zig").ScalarTypeExtension;
const SchemaDefinition = @import("../ast/schema_definition.zig").SchemaDefinition;
const SchemaExtension = @import("../ast/schema_extension.zig").SchemaExtension;
const SelectionSet = @import("../ast/selection_set.zig").SelectionSet;
const Type = @import("../ast/type.zig").Type;
const UnionTypeDefinition = @import("../ast/union_type_definition.zig").UnionTypeDefinition;
const UnionTypeExtension = @import("../ast/union_type_extension.zig").UnionTypeExtension;
const VariableDefinition = @import("../ast/variable_definition.zig").VariableDefinition;

pub fn getDocumentGql(printer: *Printer) !void {
    for (printer.document.definitions.items, 0..) |definition, i| {
        try getGqlFromExecutableDefinition(printer, definition);
        if (i < printer.document.definitions.items.len - 1) {
            try printer.append("\n\n");
        }
    }
    try printer.appendByte('\n');
}

pub fn getGqlFromExecutableDefinition(printer: *Printer, definition: ExecutableDefinition) !void {
    return switch (definition) {
        .fragmentDefinition => |fragmentDefinition| {
            try getGqlFomFragmentDefinition(printer, fragmentDefinition);
        },
        .operationDefinition => |operationDefinition| {
            try getGqlFomOperationDefinition(printer, operationDefinition);
        },
        .schemaDefinition => |schemaDefinition| {
            try getGqlFomSchemaDefinition(printer, schemaDefinition);
        },
        .objectTypeDefinition => |objectTypeDefinition| {
            try getGqlFromObjectTypeDefinition(printer, objectTypeDefinition);
        },
        .unionTypeDefinition => |unionTypeDefinition| {
            try getGqlFromUnionTypeDefinition(printer, unionTypeDefinition);
        },
        .directiveDefinition => |directiveDefinition| {
            try getGqlFomDirectiveDefinition(printer, directiveDefinition);
        },
        .scalarTypeDefinition => |scalarTypeDefinition| {
            try getGqlFomScalarTypeDefinition(printer, scalarTypeDefinition);
        },
        .interfaceTypeDefinition => |interfaceTypeDefinition| {
            try getGqlFromInterfaceTypeDefinition(printer, interfaceTypeDefinition);
        },
        .enumTypeDefinition => |enumTypeDefinition| {
            try getGqlFromEnumTypeDefinition(printer, enumTypeDefinition);
        },
        .enumTypeExtension => |enumTypeExtension| {
            try getGqlFromEnumTypeExtension(printer, enumTypeExtension);
        },
        .inputObjectTypeDefinition => |inputObjectTypeDefinition| {
            try getGqlFromInputObjectTypeDefinition(printer, inputObjectTypeDefinition);
        },
        .inputObjectTypeExtension => |inputObjectTypeExtension| {
            try getGqlFromInputObjectTypeExtension(printer, inputObjectTypeExtension);
        },
        .objectTypeExtension => |objectTypeExtension| {
            try getGqlFromObjectTypeExtension(printer, objectTypeExtension);
        },
        .interfaceTypeExtension => |interfaceTypeExtension| {
            try getGqlFromInterfaceTypeExtension(printer, interfaceTypeExtension);
        },
        .unionTypeExtension => |unionTypeExtension| {
            try getGqlFromUnionTypeExtension(printer, unionTypeExtension);
        },
        .scalarTypeExtension => |scalarTypeExtension| {
            try getGqlFromScalarTypeExtension(printer, scalarTypeExtension);
        },
        .schemaExtension => |schemaExtension| {
            try getGqlFromSchemaExtension(printer, schemaExtension);
        },
    };
}

fn getGqlFromInputObjectTypeDefinition(printer: *Printer, inputObjectTypeDefinition: InputObjectTypeDefinition) !void {
    if (inputObjectTypeDefinition.description) |description| {
        try printer.append(description);
        try printer.newLine();
    }
    try printer.append("input ");
    try printer.append(inputObjectTypeDefinition.name);
    if (inputObjectTypeDefinition.directives.len > 0) {
        try getGqlFromDirectiveList(printer, inputObjectTypeDefinition.directives);
    }
    try printer.openBrace();

    for (inputObjectTypeDefinition.fields) |fieldDefinition| {
        try printer.newLine();
        try getGqlFromInputValueDefinition(printer, fieldDefinition, InputValueSpacing.newLine);
    }

    try printer.closeBrace();
}

fn getGqlFromInputObjectTypeExtension(printer: *Printer, inputObjectTypeExtension: InputObjectTypeExtension) !void {
    try printer.append("extend input ");
    try printer.append(inputObjectTypeExtension.name);
    if (inputObjectTypeExtension.directives.len > 0) {
        try getGqlFromDirectiveList(printer, inputObjectTypeExtension.directives);
    }
    try printer.openBrace();

    for (inputObjectTypeExtension.fields) |fieldDefinition| {
        try printer.newLine();
        try getGqlFromInputValueDefinition(printer, fieldDefinition, InputValueSpacing.newLine);
    }

    try printer.closeBrace();
}

fn getGqlFromEnumTypeDefinition(printer: *Printer, enumTypeDefinition: EnumTypeDefinition) !void {
    if (enumTypeDefinition.description) |description| {
        try printer.append(description);
        try printer.newLine();
    }
    try printer.append("enum ");
    try printer.append(enumTypeDefinition.name);
    if (enumTypeDefinition.directives.len > 0) {
        try getGqlFromDirectiveList(printer, enumTypeDefinition.directives);
    }
    try printer.openBrace();

    for (enumTypeDefinition.values) |value| {
        try printer.newLine();
        try printer.append(value.name);
        if (value.directives.len > 0) {
            try getGqlFromDirectiveList(printer, value.directives);
        }
    }

    try printer.closeBrace();
}

fn getGqlFromEnumTypeExtension(printer: *Printer, enumTypeExtension: EnumTypeExtension) !void {
    try printer.append("extend enum ");
    try printer.append(enumTypeExtension.name);
    if (enumTypeExtension.directives.len > 0) {
        try getGqlFromDirectiveList(printer, enumTypeExtension.directives);
    }
    try printer.openBrace();

    for (enumTypeExtension.values) |value| {
        try printer.newLine();
        try printer.append(value.name);
        if (value.directives.len > 0) {
            try getGqlFromDirectiveList(printer, value.directives);
        }
    }

    try printer.closeBrace();
}

fn getGqlFromInterfaceTypeDefinition(printer: *Printer, interfaceTypeDefinition: InterfaceTypeDefinition) !void {
    if (interfaceTypeDefinition.description) |description| {
        try printer.append(description);
        try printer.newLine();
    }
    try printer.append("interface ");
    try printer.append(interfaceTypeDefinition.name);
    if (interfaceTypeDefinition.interfaces.len > 0) {
        try getGqlFromImplementedInterfaces(printer, interfaceTypeDefinition.interfaces);
    }
    if (interfaceTypeDefinition.directives.len > 0) {
        try getGqlFromDirectiveList(printer, interfaceTypeDefinition.directives);
    }
    try printer.openBrace();

    for (interfaceTypeDefinition.fields) |fieldDefinition| {
        try printer.newLine();
        try getGqlFromFieldDefinition(printer, fieldDefinition);
    }

    try printer.closeBrace();
}

fn getGqlFromObjectTypeDefinition(printer: *Printer, objectTypeDefinition: ObjectTypeDefinition) !void {
    if (objectTypeDefinition.description) |description| {
        try printer.append(description);
        try printer.newLine();
    }
    try printer.append("type ");
    try printer.append(objectTypeDefinition.name);
    if (objectTypeDefinition.interfaces.len > 0) {
        try getGqlFromImplementedInterfaces(printer, objectTypeDefinition.interfaces);
    }
    if (objectTypeDefinition.directives.len > 0) {
        try getGqlFromDirectiveList(printer, objectTypeDefinition.directives);
    }
    try printer.openBrace();

    for (objectTypeDefinition.fields) |fieldDefinition| {
        try printer.newLine();
        try getGqlFromFieldDefinition(printer, fieldDefinition);
    }

    try printer.closeBrace();
}

fn getGqlFromFieldDefinition(printer: *Printer, fieldDefinition: FieldDefinition) !void {
    if (fieldDefinition.description) |description| {
        try printer.append(description);
        try printer.newLine();
    }
    try printer.append(fieldDefinition.name);
    if (fieldDefinition.arguments.len > 0) {
        try printer.appendByte('(');
        for (fieldDefinition.arguments, 0..) |inputValueDefinition, i| {
            if (i > 0) try printer.append(", ");
            try getGqlFromInputValueDefinition(printer, inputValueDefinition, InputValueSpacing.space);
        }
        try printer.appendByte(')');
    }
    try printer.append(": ");
    try getGqlFromType(printer, fieldDefinition.type);
    if (fieldDefinition.directives.len > 0) {
        try getGqlFromDirectiveList(printer, fieldDefinition.directives);
    }
}

const InputValueSpacing = enum { space, newLine };

fn getGqlFromInputValueDefinition(printer: *Printer, inputValueDefinition: InputValueDefinition, spacing: InputValueSpacing) !void {
    if (inputValueDefinition.description) |description| {
        try printer.append(description);
        if (spacing == InputValueSpacing.space) {
            try printer.appendByte(' ');
        } else {
            try printer.newLine();
        }
    }
    try printer.append(inputValueDefinition.name);
    try printer.append(": ");
    try getGqlFromType(printer, inputValueDefinition.value);
    if (inputValueDefinition.defaultValue) |defaultValue| {
        try printer.append(" = ");
        try getGqlInputValue(printer, defaultValue);
    }
    if (inputValueDefinition.directives.len > 0) {
        try getGqlFromDirectiveList(printer, inputValueDefinition.directives);
    }
}

fn getGqlFromUnionTypeDefinition(printer: *Printer, unionTypeDefinition: UnionTypeDefinition) !void {
    if (unionTypeDefinition.description) |description| {
        try printer.append(description);
        try printer.newLine();
    }
    try printer.append("union ");
    try printer.append(unionTypeDefinition.name);
    if (unionTypeDefinition.directives.len > 0) {
        try getGqlFromDirectiveList(printer, unionTypeDefinition.directives);
    }
    try printer.append(" = ");
    for (unionTypeDefinition.types, 0..) |t, i| {
        if (i > 0) try printer.append(" | ");
        try getGqlFromType(printer, t);
    }
}

fn getGqlFomSchemaDefinition(printer: *Printer, schemaDefinition: SchemaDefinition) !void {
    if (schemaDefinition.description) |description| {
        try printer.append(description);
        try printer.newLine();
    }
    try printer.append("schema");
    if (schemaDefinition.directives.len > 0) {
        try getGqlFromDirectiveList(printer, schemaDefinition.directives);
    }
    try printer.openBrace();

    for (schemaDefinition.operationTypes, 0..) |operationType, i| {
        if (i > 0) try printer.appendByte(' ');
        try getGqlFromOperationTypeDefinition(printer, operationType);
    }
    try printer.closeBrace();
}

fn getGqlFromOperationTypeDefinition(printer: *Printer, operationTypeDefinition: OperationTypeDefinition) !void {
    try printer.newLine();
    try printer.append(operationTypeDefinition.operation);
    try printer.append(": ");
    try printer.append(operationTypeDefinition.name);
}

fn getGqlFromOperationType(printer: *Printer, operationType: OperationType) !void {
    switch (operationType) {
        .query => try printer.append("query"),
        .mutation => try printer.append("mutation"),
        .subscription => try printer.append("subscription"),
    }
}

fn getGqlFomOperationDefinition(printer: *Printer, operationDefinition: OperationDefinition) !void {
    switch (operationDefinition.operation) {
        .query => {
            try printer.append("query ");
        },
        .mutation => {
            try printer.append("mutation ");
        },
        .subscription => {
            try printer.append("subscription ");
        },
    }
    if (operationDefinition.name) |name| {
        try printer.append(name);
    }
    if (operationDefinition.variableDefinitions.len > 0) {
        try printer.appendByte('(');
        for (operationDefinition.variableDefinitions, 0..) |variableDefinition, i| {
            if (i > 0) try printer.append(", ");
            try getGqlVariableDefinition(printer, variableDefinition);
        }
        try printer.appendByte(')');
    }
    if (operationDefinition.directives.len > 0) {
        try getGqlFromDirectiveList(printer, operationDefinition.directives);
    }
    try getGqlFromSelectionSet(printer, operationDefinition.selectionSet);
}

fn getGqlFomScalarTypeDefinition(printer: *Printer, scalarTypeDefinition: ScalarTypeDefinition) !void {
    if (scalarTypeDefinition.description) |description| {
        try printer.append(description);
        try printer.newLine();
    }
    try printer.append("scalar ");
    try printer.append(scalarTypeDefinition.name);
    if (scalarTypeDefinition.directives.len > 0) {
        try getGqlFromDirectiveList(printer, scalarTypeDefinition.directives);
    }
}

fn getGqlFomFragmentDefinition(printer: *Printer, fragmentDefinition: FragmentDefinition) !void {
    try printer.append("fragment ");
    try printer.append(fragmentDefinition.name);
    try printer.append(" on ");
    try getGqlFromType(printer, fragmentDefinition.typeCondition);
    if (fragmentDefinition.directives.len > 0) {
        try getGqlFromDirectiveList(printer, fragmentDefinition.directives);
    }
    try getGqlFromSelectionSet(printer, fragmentDefinition.selectionSet);
}

fn getGqlFomDirectiveDefinition(printer: *Printer, directiveDefinition: DirectiveDefinition) !void {
    if (directiveDefinition.description) |description| {
        try printer.append(description);
        try printer.newLine();
    }
    try printer.append("directive @");
    try printer.append(directiveDefinition.name);
    if (directiveDefinition.arguments.len > 0) {
        try printer.appendByte('(');
        printer.indent();
        for (directiveDefinition.arguments) |argument| {
            try printer.newLine();
            try getGqlFromInputValueDefinition(printer, argument, InputValueSpacing.newLine);
        }
        printer.unindent();
        try printer.newLine();
        try printer.appendByte(')');
    }
    try printer.append(" on ");
    for (directiveDefinition.locations, 0..) |location, i| {
        if (i > 0) try printer.append(" | ");
        try printer.append(location);
    }
}

fn getGqlVariableDefinition(printer: *Printer, variableDefinition: VariableDefinition) !void {
    try printer.appendByte('$');
    try printer.append(variableDefinition.name);
    try printer.append(": ");
    try getGqlFromType(printer, variableDefinition.type);
    if (variableDefinition.defaultValue) |defaultValue| {
        try printer.append(" = ");
        try getGqlInputValue(printer, defaultValue);
    }
}

fn getGqlFromType(printer: *Printer, t: Type) !void {
    switch (t) {
        .namedType => |namedType| {
            try printer.append(namedType.name);
        },
        .listType => |listType| {
            try printer.appendByte('[');
            try getGqlFromType(printer, listType.elementType.*);
            try printer.appendByte(']');
        },
        .nonNullType => |nonNullType| {
            switch (nonNullType) {
                .namedType => |namedType| {
                    try printer.append(namedType.name);
                    try printer.appendByte('!');
                },
                .listType => |listType| {
                    try printer.appendByte('[');
                    try getGqlFromType(printer, listType.elementType.*);
                    try printer.append("]!");
                },
            }
        },
    }
}

fn getGqlInputValue(printer: *Printer, inputValue: InputValue) !void {
    switch (inputValue) {
        .variable => |variable| {
            try printer.appendByte('$');
            try printer.append(variable.name);
        },
        .list_value => |listValue| {
            try printer.appendByte('[');
            for (listValue.values, 0..) |item, i| {
                if (i > 0) try printer.append(", ");
                try getGqlInputValue(printer, item);
            }
            try printer.appendByte(']');
        },
        .object_value => |objectValue| {
            try printer.appendByte('{');
            for (objectValue.fields, 0..) |field, i| {
                if (i > 0) try printer.append(", ");
                try printer.append(field.name);
                try printer.append(": ");
                try getGqlInputValue(printer, field.value);
            }
            try printer.appendByte('}');
        },
        .boolean_value => |booleanValue| {
            try printer.append(if (booleanValue.value) "true" else "false");
        },
        .int_value => |intValue| {
            const intStr = try std.fmt.allocPrint(printer.allocator, "{d}", .{intValue.value});
            defer printer.allocator.free(intStr);
            try printer.append(intStr);
        },
        .float_value => |floatValue| {
            const floatStr = try std.fmt.allocPrint(printer.allocator, "{d}", .{floatValue.value});
            defer printer.allocator.free(floatStr);
            try printer.append(floatStr);
        },
        .string_value => |stringValue| {
            const stringStr = try std.fmt.allocPrint(printer.allocator, "{s}", .{stringValue.value});
            defer printer.allocator.free(stringStr);
            try printer.append(stringStr);
        },
        .null_value => {
            try printer.append("null");
        },
        .enum_value => |enumValue| {
            try printer.append(enumValue.name);
        },
    }
}

fn getGqlFromDirective(printer: *Printer, directive: Directive) !void {
    try printer.append(" @");
    try printer.append(directive.name);
    if (directive.arguments.len > 0) {
        try printer.appendByte('(');
        for (directive.arguments, 0..) |argument, i| {
            if (i > 0) try printer.append(", ");
            try getGqlFromArgument(printer, argument);
        }
        try printer.appendByte(')');
    }
}

fn getGqlFromArgument(printer: *Printer, argument: Argument) !void {
    try printer.append(argument.name);
    try printer.append(": ");
    try getGqlInputValue(printer, argument.value);
}

fn getGqlFromSelectionSet(printer: *Printer, selectionSet: SelectionSet) !void {
    try printer.openBrace();

    for (selectionSet.selections) |selection| {
        try printer.newLine();
        switch (selection) {
            .field => |field| {
                try getGqlFromField(printer, field);
            },
            .fragmentSpread => |fragmentSpread| {
                try printer.append("...");
                try printer.append(fragmentSpread.name);
                if (fragmentSpread.directives.len > 0) {
                    try getGqlFromDirectiveList(printer, fragmentSpread.directives);
                }
            },
            .inlineFragment => |inlineFragment| {
                try printer.append("... on ");
                try printer.append(inlineFragment.typeCondition);
                try getGqlFromSelectionSet(printer, inlineFragment.selectionSet);
                if (inlineFragment.directives.len > 0) {
                    try getGqlFromDirectiveList(printer, inlineFragment.directives);
                }
            },
        }
    }

    try printer.closeBrace();
}

fn getGqlFromField(printer: *Printer, field: Field) !void {
    if (field.alias) |alias| {
        try printer.append(alias);
        try printer.append(": ");
    }
    try printer.append(field.name);
    if (field.arguments.len > 0) {
        try printer.appendByte('(');
        for (field.arguments, 0..) |argument, i| {
            if (i > 0) try printer.append(", ");
            try getGqlFromArgument(printer, argument);
        }
        try printer.appendByte(')');
    }
    if (field.directives.len > 0) {
        try getGqlFromDirectiveList(printer, field.directives);
    }
}

fn getGqlFromDirectiveList(printer: *Printer, directives: []Directive) !void {
    for (directives) |directive| {
        try getGqlFromDirective(printer, directive);
    }
}

fn getGqlFromImplementedInterfaces(printer: *Printer, interfaces: []Interface) !void {
    try printer.append(" implements ");
    for (interfaces, 0..) |interface, i| {
        if (i > 0) try printer.append(" & ");
        try getGqlFromType(printer, interface.type);
    }
}

fn getGqlFromObjectTypeExtension(printer: *Printer, objectTypeExtension: ObjectTypeExtension) !void {
    try printer.append("extend type ");
    try printer.append(objectTypeExtension.name);
    if (objectTypeExtension.interfaces.len > 0) {
        try getGqlFromImplementedInterfaces(printer, objectTypeExtension.interfaces);
    }
    if (objectTypeExtension.directives.len > 0) {
        try getGqlFromDirectiveList(printer, objectTypeExtension.directives);
    }
    try printer.openBrace();

    for (objectTypeExtension.fields) |fieldDefinition| {
        try printer.newLine();
        try getGqlFromFieldDefinition(printer, fieldDefinition);
    }

    try printer.closeBrace();
}

fn getGqlFromInterfaceTypeExtension(printer: *Printer, interfaceTypeExtension: InterfaceTypeExtension) !void {
    try printer.append("extend interface ");
    try printer.append(interfaceTypeExtension.name);
    if (interfaceTypeExtension.interfaces.len > 0) {
        try getGqlFromImplementedInterfaces(printer, interfaceTypeExtension.interfaces);
    }
    if (interfaceTypeExtension.directives.len > 0) {
        try getGqlFromDirectiveList(printer, interfaceTypeExtension.directives);
    }
    try printer.openBrace();
    for (interfaceTypeExtension.fields) |fieldDefinition| {
        try printer.newLine();
        try getGqlFromFieldDefinition(printer, fieldDefinition);
    }
    try printer.closeBrace();
}

fn getGqlFromUnionTypeExtension(printer: *Printer, unionTypeExtension: UnionTypeExtension) !void {
    try printer.append("extend union ");
    try printer.append(unionTypeExtension.name);
    if (unionTypeExtension.directives.len > 0) {
        try getGqlFromDirectiveList(printer, unionTypeExtension.directives);
    }
    try printer.append(" = ");
    for (unionTypeExtension.types, 0..) |t, i| {
        if (i > 0) try printer.append(" | ");
        try getGqlFromType(printer, t);
    }
}

fn getGqlFromScalarTypeExtension(printer: *Printer, scalarTypeExtension: ScalarTypeExtension) !void {
    try printer.append("extend scalar ");
    try printer.append(scalarTypeExtension.name);
    if (scalarTypeExtension.directives.len > 0) {
        try getGqlFromDirectiveList(printer, scalarTypeExtension.directives);
    }
}

fn getGqlFromSchemaExtension(printer: *Printer, schemaExtension: SchemaExtension) !void {
    try printer.append("extend schema");
    if (schemaExtension.directives.len > 0) {
        try getGqlFromDirectiveList(printer, schemaExtension.directives);
    }
    try printer.openBrace();

    for (schemaExtension.operationTypes, 0..) |operationType, i| {
        if (i > 0) try printer.appendByte(' ');
        try getGqlFromOperationTypeDefinition(printer, operationType);
    }

    try printer.closeBrace();
}
