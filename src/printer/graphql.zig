const std = @import("std");
const Allocator = std.mem.Allocator;

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
const Selection = @import("../ast/selection.zig").Selection;
const SelectionSet = @import("../ast/selection_set.zig").SelectionSet;
const Type = @import("../ast/type.zig").Type;
const UnionTypeDefinition = @import("../ast/union_type_definition.zig").UnionTypeDefinition;
const UnionTypeExtension = @import("../ast/union_type_extension.zig").UnionTypeExtension;
const VariableDefinition = @import("../ast/variable_definition.zig").VariableDefinition;

pub fn getGqlFromExecutableDefinition(definition: ExecutableDefinition, allocator: Allocator) ![]u8 {
    return switch (definition) {
        .fragmentDefinition => |fragmentDefinition| {
            return try getGqlFomFragmentDefinition(fragmentDefinition, allocator);
        },
        .operationDefinition => |operationDefinition| {
            return try getGqlFomOperationDefinition(operationDefinition, allocator);
        },
        .schemaDefinition => |schemaDefinition| {
            return try getGqlFomSchemaDefinition(schemaDefinition, allocator);
        },
        .objectTypeDefinition => |objectTypeDefinition| {
            return try getGqlFromObjectTypeDefinition(objectTypeDefinition, allocator);
        },
        .unionTypeDefinition => |unionTypeDefinition| {
            return try getGqlFromUnionTypeDefinition(unionTypeDefinition, allocator);
        },
        .directiveDefinition => |directiveDefinition| {
            return try getGqlFomDirectiveDefinition(directiveDefinition, allocator);
        },
        .scalarTypeDefinition => |scalarTypeDefinition| {
            return try getGqlFomScalarTypeDefinition(scalarTypeDefinition, allocator);
        },
        .interfaceTypeDefinition => |interfaceTypeDefinition| {
            return try getGqlFromInterfaceTypeDefinition(interfaceTypeDefinition, allocator);
        },
        .enumTypeDefinition => |enumTypeDefinition| {
            return try getGqlFromEnumTypeDefinition(enumTypeDefinition, allocator);
        },
        .enumTypeExtension => |enumTypeExtension| {
            return try getGqlFromEnumTypeExtension(enumTypeExtension, allocator);
        },
        .inputObjectTypeDefinition => |inputObjectTypeDefinition| {
            return try getGqlFromInputObjectTypeDefinition(inputObjectTypeDefinition, allocator);
        },
        .inputObjectTypeExtension => |inputObjectTypeExtension| {
            return try getGqlFromInputObjectTypeExtension(inputObjectTypeExtension, allocator);
        },
        .objectTypeExtension => |objectTypeExtension| {
            return try getGqlFromObjectTypeExtension(objectTypeExtension, allocator);
        },
        .interfaceTypeExtension => |interfaceTypeExtension| {
            return try getGqlFromInterfaceTypeExtension(interfaceTypeExtension, allocator);
        },
        .unionTypeExtension => |unionTypeExtension| {
            return try getGqlFromUnionTypeExtension(unionTypeExtension, allocator);
        },
        .scalarTypeExtension => |scalarTypeExtension| {
            return try getGqlFromScalarTypeExtension(scalarTypeExtension, allocator);
        },
        .schemaExtension => |schemaExtension| {
            return try getGqlFromSchemaExtension(schemaExtension, allocator);
        },
    };
}

fn getGqlFromInputObjectTypeDefinition(inputObjectTypeDefinition: InputObjectTypeDefinition, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    if (inputObjectTypeDefinition.description) |description| {
        try str.appendSlice(description);
        try str.appendSlice(" ");
    }
    try str.appendSlice("input ");
    try str.appendSlice(inputObjectTypeDefinition.name);
    if (inputObjectTypeDefinition.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(inputObjectTypeDefinition.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    try str.appendSlice(" {");
    for (inputObjectTypeDefinition.fields, 0..) |fieldDefinition, i| {
        if (i > 0) try str.append(' ');
        const fieldStr = try getGqlFromInputValueDefinition(fieldDefinition, allocator);
        defer allocator.free(fieldStr);
        try str.appendSlice(fieldStr);
    }
    try str.appendSlice("}");
    return str.toOwnedSlice();
}

fn getGqlFromInputObjectTypeExtension(inputObjectTypeExtension: InputObjectTypeExtension, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    try str.appendSlice("extend input ");
    try str.appendSlice(inputObjectTypeExtension.name);
    if (inputObjectTypeExtension.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(inputObjectTypeExtension.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    try str.appendSlice(" {");
    for (inputObjectTypeExtension.fields, 0..) |fieldDefinition, i| {
        if (i > 0) try str.append(' ');
        const fieldStr = try getGqlFromInputValueDefinition(fieldDefinition, allocator);
        defer allocator.free(fieldStr);
        try str.appendSlice(fieldStr);
    }
    try str.appendSlice("}");
    return str.toOwnedSlice();
}

fn getGqlFromEnumTypeDefinition(enumTypeDefinition: EnumTypeDefinition, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    if (enumTypeDefinition.description) |description| {
        try str.appendSlice(description);
        try str.appendSlice(" ");
    }
    try str.appendSlice("enum ");
    try str.appendSlice(enumTypeDefinition.name);
    if (enumTypeDefinition.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(enumTypeDefinition.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    try str.appendSlice(" {");
    for (enumTypeDefinition.values, 0..) |value, i| {
        if (i > 0) try str.append(' ');
        try str.appendSlice(value.name);
        if (value.directives.len > 0) {
            const valueDirectivesStr = try getGqlFromDirectiveList(value.directives, allocator);
            defer allocator.free(valueDirectivesStr);
            try str.appendSlice(valueDirectivesStr);
        }
    }
    try str.appendSlice("}");
    return str.toOwnedSlice();
}

fn getGqlFromEnumTypeExtension(enumTypeExtension: EnumTypeExtension, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    try str.appendSlice("extend enum ");
    try str.appendSlice(enumTypeExtension.name);
    if (enumTypeExtension.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(enumTypeExtension.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    try str.appendSlice(" {");
    for (enumTypeExtension.values, 0..) |value, i| {
        if (i > 0) try str.append(' ');
        try str.appendSlice(value.name);
        if (value.directives.len > 0) {
            const valueDirectivesStr = try getGqlFromDirectiveList(value.directives, allocator);
            defer allocator.free(valueDirectivesStr);
            try str.appendSlice(valueDirectivesStr);
        }
    }
    try str.appendSlice("}");
    return str.toOwnedSlice();
}

fn getGqlFromInterfaceTypeDefinition(interfaceTypeDefinition: InterfaceTypeDefinition, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    if (interfaceTypeDefinition.description) |description| {
        try str.appendSlice(description);
        try str.appendSlice(" ");
    }
    try str.appendSlice("interface ");
    try str.appendSlice(interfaceTypeDefinition.name);
    if (interfaceTypeDefinition.interfaces.len > 0) {
        const gql = try getGqlFromImplementedInterfaces(interfaceTypeDefinition.interfaces, allocator);
        defer allocator.free(gql);
        try str.appendSlice(gql);
    }
    if (interfaceTypeDefinition.directives.len > 0) {
        const gql = try getGqlFromDirectiveList(interfaceTypeDefinition.directives, allocator);
        defer allocator.free(gql);
        try str.appendSlice(gql);
    }
    try str.appendSlice(" {");
    for (interfaceTypeDefinition.fields, 0..) |fieldDefinition, i| {
        if (i > 0) try str.append(' ');
        const gql = try getGqlFromFieldDefinition(fieldDefinition, allocator);
        defer allocator.free(gql);
        try str.appendSlice(gql);
    }
    try str.appendSlice("}");
    return str.toOwnedSlice();
}

fn getGqlFromObjectTypeDefinition(objectTypeDefinition: ObjectTypeDefinition, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    if (objectTypeDefinition.description) |description| {
        try str.appendSlice(description);
        try str.appendSlice(" ");
    }
    try str.appendSlice("type ");
    try str.appendSlice(objectTypeDefinition.name);
    if (objectTypeDefinition.interfaces.len > 0) {
        const interfacesStr = try getGqlFromImplementedInterfaces(objectTypeDefinition.interfaces, allocator);
        defer allocator.free(interfacesStr);
        try str.appendSlice(interfacesStr);
    }
    if (objectTypeDefinition.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(objectTypeDefinition.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    try str.appendSlice(" {");
    for (objectTypeDefinition.fields, 0..) |fieldDefinition, i| {
        if (i > 0) try str.append(' ');
        const fieldStr = try getGqlFromFieldDefinition(fieldDefinition, allocator);
        defer allocator.free(fieldStr);
        try str.appendSlice(fieldStr);
    }
    try str.appendSlice("}");
    return str.toOwnedSlice();
}

fn getGqlFromFieldDefinition(fieldDefinition: FieldDefinition, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    if (fieldDefinition.description) |description| {
        try str.appendSlice(description);
        try str.appendSlice(" ");
    }
    try str.appendSlice(fieldDefinition.name);
    if (fieldDefinition.arguments.len > 0) {
        try str.appendSlice("(");
        for (fieldDefinition.arguments, 0..) |inputValueDefinition, i| {
            if (i > 0) try str.appendSlice(", ");
            const argStr = try getGqlFromInputValueDefinition(inputValueDefinition, allocator);
            defer allocator.free(argStr);
            try str.appendSlice(argStr);
        }
        try str.appendSlice(")");
    }
    try str.appendSlice(": ");
    const typeStr = try getGqlFromType(fieldDefinition.type, allocator);
    defer allocator.free(typeStr);
    try str.appendSlice(typeStr);
    if (fieldDefinition.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(fieldDefinition.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    return str.toOwnedSlice();
}

fn getGqlFromInputValueDefinition(inputValueDefinition: InputValueDefinition, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    if (inputValueDefinition.description) |description| {
        try str.appendSlice(description);
        try str.appendSlice(" ");
    }
    try str.appendSlice(inputValueDefinition.name);
    try str.appendSlice(": ");
    const typeStr = try getGqlFromType(inputValueDefinition.value, allocator);
    defer allocator.free(typeStr);
    try str.appendSlice(typeStr);
    if (inputValueDefinition.defaultValue) |defaultValue| {
        try str.appendSlice(" = ");
        const defaultValueStr = try getGqlInputValue(defaultValue, allocator);
        defer allocator.free(defaultValueStr);
        try str.appendSlice(defaultValueStr);
    }
    if (inputValueDefinition.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(inputValueDefinition.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    return str.toOwnedSlice();
}

fn getGqlFromUnionTypeDefinition(unionTypeDefinition: UnionTypeDefinition, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    if (unionTypeDefinition.description) |description| {
        try str.appendSlice(description);
        try str.appendSlice(" ");
    }
    try str.appendSlice("union ");
    try str.appendSlice(unionTypeDefinition.name);
    if (unionTypeDefinition.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(unionTypeDefinition.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    try str.appendSlice(" = ");
    for (unionTypeDefinition.types, 0..) |t, i| {
        if (i > 0) try str.appendSlice(" | ");
        const typeStr = try getGqlFromType(t, allocator);
        defer allocator.free(typeStr);
        try str.appendSlice(typeStr);
    }
    return str.toOwnedSlice();
}

fn getGqlFomSchemaDefinition(schemaDefinition: SchemaDefinition, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    if (schemaDefinition.description) |description| {
        try str.appendSlice(description);
        try str.appendSlice(" ");
    }
    try str.appendSlice("schema");
    if (schemaDefinition.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(schemaDefinition.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    try str.appendSlice(" {");
    for (schemaDefinition.operationTypes, 0..) |operationType, i| {
        if (i > 0) try str.append(' ');
        const operationTypeStr = try getGqlFromOperationTypeDefinition(operationType, allocator);
        defer allocator.free(operationTypeStr);
        try str.appendSlice(operationTypeStr);
    }
    try str.appendSlice("}");
    return str.toOwnedSlice();
}

fn getGqlFromOperationTypeDefinition(operationTypeDefinition: OperationTypeDefinition, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    try str.appendSlice(operationTypeDefinition.operation);
    try str.appendSlice(": ");
    try str.appendSlice(operationTypeDefinition.name);
    return str.toOwnedSlice();
}

fn getGqlFromOperationType(operationType: OperationType, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    switch (operationType) {
        .query => try str.appendSlice("query"),
        .mutation => try str.appendSlice("mutation"),
        .subscription => try str.appendSlice("subscription"),
    }
    return str.toOwnedSlice();
}

fn getGqlFomOperationDefinition(operationDefinition: OperationDefinition, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    switch (operationDefinition.operation) {
        .query => {
            try str.appendSlice("query ");
        },
        .mutation => {
            try str.appendSlice("mutation ");
        },
        .subscription => {
            try str.appendSlice("subscription ");
        },
    }
    if (operationDefinition.name) |name| {
        try str.appendSlice(name);
    }
    if (operationDefinition.variableDefinitions.len > 0) {
        try str.appendSlice("(");
        for (operationDefinition.variableDefinitions, 0..) |variableDefinition, i| {
            if (i > 0) try str.appendSlice(", ");
            const varDefStr = try getGqlVariableDefinition(variableDefinition, allocator);
            defer allocator.free(varDefStr);
            try str.appendSlice(varDefStr);
        }
        try str.appendSlice(")");
    }
    if (operationDefinition.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(operationDefinition.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    try str.appendSlice(" ");
    const selectionSetStr = try getGqlFromSelectionSet(operationDefinition.selectionSet, allocator);
    defer allocator.free(selectionSetStr);
    try str.appendSlice(selectionSetStr);

    return str.toOwnedSlice();
}

fn getGqlFomScalarTypeDefinition(scalarTypeDefinition: ScalarTypeDefinition, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    if (scalarTypeDefinition.description) |description| {
        try str.appendSlice(description);
        try str.appendSlice(" ");
    }
    try str.appendSlice("scalar ");
    try str.appendSlice(scalarTypeDefinition.name);
    if (scalarTypeDefinition.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(scalarTypeDefinition.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    return str.toOwnedSlice();
}

fn getGqlFomFragmentDefinition(fragmentDefinition: FragmentDefinition, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    try str.appendSlice("fragment ");
    try str.appendSlice(fragmentDefinition.name);
    try str.appendSlice(" on ");
    const typeStr = try getGqlFromType(fragmentDefinition.typeCondition, allocator);
    defer allocator.free(typeStr);
    try str.appendSlice(typeStr);
    if (fragmentDefinition.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(fragmentDefinition.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    const selectionSetStr = try getGqlFromSelectionSet(fragmentDefinition.selectionSet, allocator);
    defer allocator.free(selectionSetStr);
    try str.appendSlice(selectionSetStr);
    return str.toOwnedSlice();
}

fn getGqlFomDirectiveDefinition(directiveDefinition: DirectiveDefinition, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    if (directiveDefinition.description) |description| {
        try str.appendSlice(description);
        try str.appendSlice(" ");
    }
    try str.appendSlice("directive @");
    try str.appendSlice(directiveDefinition.name);
    if (directiveDefinition.arguments.len > 0) {
        try str.appendSlice("(");
        for (directiveDefinition.arguments, 0..) |argument, i| {
            if (i > 0) try str.appendSlice(", ");
            const argStr = try getGqlFromInputValueDefinition(argument, allocator);
            defer allocator.free(argStr);
            try str.appendSlice(argStr);
        }
        try str.appendSlice(")");
    }
    try str.appendSlice(" on ");
    for (directiveDefinition.locations, 0..) |location, i| {
        if (i > 0) try str.appendSlice(" | ");
        try str.appendSlice(location);
    }
    return str.toOwnedSlice();
}

fn getGqlVariableDefinition(variableDefinition: VariableDefinition, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    try str.appendSlice("$");
    try str.appendSlice(variableDefinition.name);
    try str.appendSlice(": ");
    const typeStr = try getGqlFromType(variableDefinition.type, allocator);
    defer allocator.free(typeStr);
    try str.appendSlice(typeStr);
    if (variableDefinition.defaultValue) |defaultValue| {
        try str.appendSlice(" = ");
        const defaultValueStr = try getGqlInputValue(defaultValue, allocator);
        defer allocator.free(defaultValueStr);
        try str.appendSlice(defaultValueStr);
    }
    return str.toOwnedSlice();
}

fn getGqlFromType(t: Type, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);

    switch (t) {
        .namedType => |namedType| {
            try str.appendSlice(namedType.name);
        },
        .listType => |listType| {
            try str.appendSlice("[");
            const elementTypeStr = try getGqlFromType(listType.elementType.*, allocator);
            defer allocator.free(elementTypeStr);
            try str.appendSlice(elementTypeStr);
            try str.appendSlice("]");
        },
        .nonNullType => |nonNullType| {
            switch (nonNullType) {
                .namedType => |namedType| {
                    try str.appendSlice(namedType.name);
                    try str.appendSlice("!");
                },
                .listType => |listType| {
                    try str.appendSlice("[");
                    const elementTypeStr = try getGqlFromType(listType.elementType.*, allocator);
                    defer allocator.free(elementTypeStr);
                    try str.appendSlice(elementTypeStr);
                    try str.appendSlice("]!");
                },
            }
        },
    }

    return str.toOwnedSlice();
}

fn getGqlInputValue(inputValue: InputValue, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    switch (inputValue) {
        .variable => |variable| {
            try str.appendSlice("$");
            try str.appendSlice(variable.name);
        },
        .list_value => |listValue| {
            try str.appendSlice("[");
            for (listValue.values, 0..) |item, i| {
                if (i > 0) try str.appendSlice(", ");
                const itemStr = try getGqlInputValue(item, allocator);
                defer allocator.free(itemStr);
                try str.appendSlice(itemStr);
            }
            try str.appendSlice("]");
        },
        .object_value => |objectValue| {
            try str.appendSlice("{");
            for (objectValue.fields, 0..) |field, i| {
                if (i > 0) try str.appendSlice(", ");
                try str.appendSlice(field.name);
                try str.appendSlice(": ");
                const fieldValueStr = try getGqlInputValue(field.value, allocator);
                defer allocator.free(fieldValueStr);
                try str.appendSlice(fieldValueStr);
            }
            try str.appendSlice("}");
        },
        .boolean_value => |booleanValue| {
            try str.appendSlice(if (booleanValue.value) "true" else "false");
        },
        .int_value => |intValue| {
            const intStr = try std.fmt.allocPrint(allocator, "{d}", .{intValue.value});
            defer allocator.free(intStr);
            try str.appendSlice(intStr);
        },
        .float_value => |floatValue| {
            const floatStr = try std.fmt.allocPrint(allocator, "{d}", .{floatValue.value});
            defer allocator.free(floatStr);
            try str.appendSlice(floatStr);
        },
        .string_value => |stringValue| {
            const stringStr = try std.fmt.allocPrint(allocator, "{s}", .{stringValue.value});
            defer allocator.free(stringStr);
            try str.appendSlice(stringStr);
        },
        .null_value => {
            try str.appendSlice("null");
        },
        .enum_value => |enumValue| {
            try str.appendSlice(enumValue.name);
        },
    }
    return str.toOwnedSlice();
}

fn getGqlFromDirective(directive: Directive, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    try str.appendSlice(" @");
    try str.appendSlice(directive.name);
    if (directive.arguments.len > 0) {
        try str.appendSlice("(");
        for (directive.arguments, 0..) |argument, i| {
            if (i > 0) try str.appendSlice(", ");
            const argStr = try getGqlFromArgument(argument, allocator);
            defer allocator.free(argStr);
            try str.appendSlice(argStr);
        }
        try str.appendSlice(")");
    }
    return str.toOwnedSlice();
}

fn getGqlFromArgument(argument: Argument, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    try str.appendSlice(argument.name);
    try str.appendSlice(": ");
    const valueStr = try getGqlInputValue(argument.value, allocator);
    defer allocator.free(valueStr);
    try str.appendSlice(valueStr);
    return str.toOwnedSlice();
}

fn getGqlFromSelectionSet(selectionSet: SelectionSet, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    try str.appendSlice("{");

    for (selectionSet.selections, 0..) |selection, i| {
        if (i > 0) try str.appendSlice(" ");
        switch (selection) {
            .field => |field| {
                const fieldStr = try getGqlFromField(field, allocator);
                defer allocator.free(fieldStr);
                try str.appendSlice(fieldStr);
            },
            .fragmentSpread => |fragmentSpread| {
                try str.appendSlice("...");
                try str.appendSlice(fragmentSpread.name);
                if (fragmentSpread.directives.len > 0) {
                    const directivesStr = try getGqlFromDirectiveList(fragmentSpread.directives, allocator);
                    defer allocator.free(directivesStr);
                    try str.appendSlice(directivesStr);
                }
            },
            .inlineFragment => |inlineFragment| {
                try str.appendSlice("... on ");
                try str.appendSlice(inlineFragment.typeCondition);
                const selectionSetStr = try getGqlFromSelectionSet(inlineFragment.selectionSet, allocator);
                defer allocator.free(selectionSetStr);
                try str.appendSlice(selectionSetStr);
                if (inlineFragment.directives.len > 0) {
                    const directivesStr = try getGqlFromDirectiveList(inlineFragment.directives, allocator);
                    defer allocator.free(directivesStr);
                    try str.appendSlice(directivesStr);
                }
            },
        }
    }
    try str.appendSlice("}");
    return str.toOwnedSlice();
}

fn getGqlFromField(field: Field, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    if (field.alias) |alias| {
        try str.appendSlice(alias);
        try str.appendSlice(": ");
    }
    try str.appendSlice(field.name);
    if (field.arguments.len > 0) {
        try str.appendSlice("(");
        for (field.arguments, 0..) |argument, i| {
            if (i > 0) try str.appendSlice(", ");
            const argStr = try getGqlFromArgument(argument, allocator);
            defer allocator.free(argStr);
            try str.appendSlice(argStr);
        }
        try str.appendSlice(")");
    }
    if (field.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(field.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    return str.toOwnedSlice();
}

fn getGqlFromDirectiveList(directives: []Directive, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    for (directives) |directive| {
        const directiveStr = try getGqlFromDirective(directive, allocator);
        defer allocator.free(directiveStr);
        try str.appendSlice(directiveStr);
    }
    return str.toOwnedSlice();
}

fn getGqlFromImplementedInterfaces(interfaces: []Interface, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    try str.appendSlice(" implements ");
    for (interfaces, 0..) |interface, i| {
        if (i > 0) try str.appendSlice(" & ");
        const interfaceStr = try getGqlFromType(interface.type, allocator);
        defer allocator.free(interfaceStr);
        try str.appendSlice(interfaceStr);
    }
    return str.toOwnedSlice();
}

fn getGqlFromObjectTypeExtension(objectTypeExtension: ObjectTypeExtension, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    try str.appendSlice("extend type ");
    try str.appendSlice(objectTypeExtension.name);
    if (objectTypeExtension.interfaces.len > 0) {
        const interfacesStr = try getGqlFromImplementedInterfaces(objectTypeExtension.interfaces, allocator);
        defer allocator.free(interfacesStr);
        try str.appendSlice(interfacesStr);
    }
    if (objectTypeExtension.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(objectTypeExtension.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    try str.appendSlice(" {");
    for (objectTypeExtension.fields, 0..) |fieldDefinition, i| {
        if (i > 0) try str.append(' ');
        const fieldStr = try getGqlFromFieldDefinition(fieldDefinition, allocator);
        defer allocator.free(fieldStr);
        try str.appendSlice(fieldStr);
    }
    try str.appendSlice("}");
    return str.toOwnedSlice();
}

fn getGqlFromInterfaceTypeExtension(interfaceTypeExtension: InterfaceTypeExtension, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    try str.appendSlice("extend interface ");
    try str.appendSlice(interfaceTypeExtension.name);
    if (interfaceTypeExtension.interfaces.len > 0) {
        const interfacesStr = try getGqlFromImplementedInterfaces(interfaceTypeExtension.interfaces, allocator);
        defer allocator.free(interfacesStr);
        try str.appendSlice(interfacesStr);
    }
    if (interfaceTypeExtension.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(interfaceTypeExtension.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    try str.appendSlice(" {");
    for (interfaceTypeExtension.fields, 0..) |fieldDefinition, i| {
        if (i > 0) try str.append(' ');
        const fieldStr = try getGqlFromFieldDefinition(fieldDefinition, allocator);
        defer allocator.free(fieldStr);
        try str.appendSlice(fieldStr);
    }
    try str.appendSlice("}");
    return str.toOwnedSlice();
}

fn getGqlFromUnionTypeExtension(unionTypeExtension: UnionTypeExtension, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    try str.appendSlice("extend union ");
    try str.appendSlice(unionTypeExtension.name);
    if (unionTypeExtension.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(unionTypeExtension.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    try str.appendSlice(" = ");
    for (unionTypeExtension.types, 0..) |t, i| {
        if (i > 0) try str.appendSlice(" | ");
        const typeStr = try getGqlFromType(t, allocator);
        defer allocator.free(typeStr);
        try str.appendSlice(typeStr);
    }
    return str.toOwnedSlice();
}

fn getGqlFromScalarTypeExtension(scalarTypeExtension: ScalarTypeExtension, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    try str.appendSlice("extend scalar ");
    try str.appendSlice(scalarTypeExtension.name);
    if (scalarTypeExtension.directives.len > 0) {
        const gql = try getGqlFromDirectiveList(scalarTypeExtension.directives, allocator);
        defer allocator.free(gql);
        try str.appendSlice(gql);
    }
    return str.toOwnedSlice();
}

fn getGqlFromSchemaExtension(schemaExtension: SchemaExtension, allocator: Allocator) ![]u8 {
    var str = std.ArrayList(u8).init(allocator);
    try str.appendSlice("extend schema");
    if (schemaExtension.directives.len > 0) {
        const directivesStr = try getGqlFromDirectiveList(schemaExtension.directives, allocator);
        defer allocator.free(directivesStr);
        try str.appendSlice(directivesStr);
    }
    try str.appendSlice(" {");
    for (schemaExtension.operationTypes, 0..) |operationType, i| {
        if (i > 0) try str.append(' ');
        const operationTypeStr = try getGqlFromOperationTypeDefinition(operationType, allocator);
        defer allocator.free(operationTypeStr);
        try str.appendSlice(operationTypeStr);
    }
    try str.appendSlice("}");
    return str.toOwnedSlice();
}
