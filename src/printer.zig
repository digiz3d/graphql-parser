const std = @import("std");
const Document = @import("ast/document.zig").Document;
const ExecutableDefinition = @import("ast/executable_definition.zig").ExecutableDefinition;
const Allocator = std.mem.Allocator;

const Argument = @import("ast/arguments.zig").Argument;
const Directive = @import("ast/directive.zig").Directive;
const OperationDefinition = @import("ast/operation_definition.zig").OperationDefinition;
const OperationType = @import("ast/operation_definition.zig").OperationType;
const FragmentDefinition = @import("ast/fragment_definition.zig").FragmentDefinition;
const DirectiveDefinition = @import("ast/directive_definition.zig").DirectiveDefinition;
const SelectionSet = @import("ast/selection_set.zig").SelectionSet;
const VariableDefinition = @import("ast/variable_definition.zig").VariableDefinition;
const Type = @import("ast/type.zig").Type;
const InputValue = @import("ast/input_value.zig").InputValue;
const Selection = @import("ast/selection.zig").Selection;
const Field = @import("ast/field.zig").Field;
const ScalarTypeDefinition = @import("ast/scalar_type_definition.zig").ScalarTypeDefinition;
const SchemaDefinition = @import("ast/schema_definition.zig").SchemaDefinition;
const OperationTypeDefinition = @import("ast/operation_type_definition.zig").OperationTypeDefinition;
const UnionTypeDefinition = @import("ast/union_type_definition.zig").UnionTypeDefinition;
const ObjectTypeDefinition = @import("ast/object_type_definition.zig").ObjectTypeDefinition;
const FieldDefinition = @import("ast/field_definition.zig").FieldDefinition;
const InputValueDefinition = @import("ast/input_value_definition.zig").InputValueDefinition;
const Interface = @import("ast/interface.zig").Interface;
const InterfaceTypeDefinition = @import("ast/interface_type_definition.zig").InterfaceTypeDefinition;
const EnumTypeDefinition = @import("ast/enum_type_definition.zig").EnumTypeDefinition;
const EnumTypeExtension = @import("ast/enum_type_extension.zig").EnumTypeExtension;
const EnumValueDefinition = @import("ast/enum_value_definition.zig").EnumValueDefinition;
const InputObjectTypeDefinition = @import("ast/input_object_type_definition.zig").InputObjectTypeDefinition;
const InputObjectTypeExtension = @import("ast/input_object_type_extension.zig").InputObjectTypeExtension;

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

    fn getGqlFromExecutableDefinition(definition: ExecutableDefinition, allocator: Allocator) ![]u8 {
        var graphQLString = std.ArrayList(u8).init(allocator);
        defer graphQLString.deinit();

        const str = switch (definition) {
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
            else => {
                return try getNotImplementedString(allocator);
            },
        };

        try graphQLString.appendSlice(str);

        return try graphQLString.toOwnedSlice();
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
            try str.appendSlice(try getGqlFromDirectiveList(inputObjectTypeDefinition.directives, allocator));
        }
        try str.appendSlice(" {");
        for (inputObjectTypeDefinition.fields, 0..) |fieldDefinition, i| {
            if (i > 0) try str.appendSlice("\n");
            try str.appendSlice(try getGqlFromInputValueDefinition(fieldDefinition, allocator));
        }
        try str.appendSlice("}");
        return str.toOwnedSlice();
    }

    fn getGqlFromInputObjectTypeExtension(inputObjectTypeExtension: InputObjectTypeExtension, allocator: Allocator) ![]u8 {
        var str = std.ArrayList(u8).init(allocator);
        try str.appendSlice("extend input ");
        try str.appendSlice(inputObjectTypeExtension.name);
        if (inputObjectTypeExtension.directives.len > 0) {
            try str.appendSlice(try getGqlFromDirectiveList(inputObjectTypeExtension.directives, allocator));
        }
        try str.appendSlice(" {");
        for (inputObjectTypeExtension.fields, 0..) |fieldDefinition, i| {
            if (i > 0) try str.appendSlice("\n");
            try str.appendSlice(try getGqlFromInputValueDefinition(fieldDefinition, allocator));
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
            try str.appendSlice(try getGqlFromDirectiveList(enumTypeDefinition.directives, allocator));
        }
        try str.appendSlice(" {");
        for (enumTypeDefinition.values, 0..) |value, i| {
            if (i > 0) try str.append(' ');
            try str.appendSlice(value.name);
            if (value.directives.len > 0) {
                try str.appendSlice(try getGqlFromDirectiveList(value.directives, allocator));
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
            try str.appendSlice(try getGqlFromDirectiveList(enumTypeExtension.directives, allocator));
        }
        try str.appendSlice(" {");
        for (enumTypeExtension.values, 0..) |value, i| {
            if (i > 0) try str.append(' ');
            try str.appendSlice(value.name);
            if (value.directives.len > 0) {
                try str.appendSlice(try getGqlFromDirectiveList(value.directives, allocator));
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
            try str.appendSlice(try getGqlFromImplementedInterfaces(interfaceTypeDefinition.interfaces, allocator));
        }
        if (interfaceTypeDefinition.directives.len > 0) {
            try str.appendSlice(try getGqlFromDirectiveList(interfaceTypeDefinition.directives, allocator));
        }
        try str.appendSlice(" {");
        for (interfaceTypeDefinition.fields, 0..) |fieldDefinition, i| {
            if (i > 0) try str.appendSlice("\n");
            try str.appendSlice(try getGqlFromFieldDefinition(fieldDefinition, allocator));
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
            try str.appendSlice(try getGqlFromImplementedInterfaces(objectTypeDefinition.interfaces, allocator));
        }
        if (objectTypeDefinition.directives.len > 0) {
            try str.appendSlice(try getGqlFromDirectiveList(objectTypeDefinition.directives, allocator));
        }
        try str.appendSlice(" {");
        for (objectTypeDefinition.fields, 0..) |fieldDefinition, i| {
            if (i > 0) try str.appendSlice("\n");
            try str.appendSlice(try getGqlFromFieldDefinition(fieldDefinition, allocator));
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
                try str.appendSlice(try getGqlFromInputValueDefinition(inputValueDefinition, allocator));
            }
            try str.appendSlice(")");
        }
        try str.appendSlice(": ");
        try str.appendSlice(try getGqlFromType(fieldDefinition.type, allocator));
        if (fieldDefinition.directives.len > 0) {
            try str.appendSlice(try getGqlFromDirectiveList(fieldDefinition.directives, allocator));
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
        if (inputValueDefinition.directives.len > 0) {
            try str.appendSlice(try getGqlFromDirectiveList(inputValueDefinition.directives, allocator));
        }
        try str.appendSlice(": ");
        try str.appendSlice(try getGqlFromType(inputValueDefinition.value, allocator));
        if (inputValueDefinition.defaultValue) |defaultValue| {
            try str.appendSlice(" = ");
            try str.appendSlice(try getGqlInputValue(defaultValue, allocator));
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
            try str.appendSlice(try getGqlFromDirectiveList(unionTypeDefinition.directives, allocator));
        }
        try str.appendSlice(" = ");
        for (unionTypeDefinition.types, 0..) |t, i| {
            if (i > 0) try str.appendSlice(" | ");
            try str.appendSlice(try getGqlFromType(t, allocator));
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
            try str.appendSlice(try getGqlFromDirectiveList(schemaDefinition.directives, allocator));
        }
        try str.appendSlice(" {");
        for (schemaDefinition.operationTypes, 0..) |operationType, i| {
            if (i > 0) try str.appendSlice("\n");
            try str.appendSlice(try getGqlFromOperationTypeDefinition(operationType, allocator));
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
                try str.appendSlice(try getGqlVariableDefinition(variableDefinition, allocator));
            }
            try str.appendSlice(")");
        }
        if (operationDefinition.directives.len > 0) {
            try str.appendSlice(try getGqlFromDirectiveList(operationDefinition.directives, allocator));
        }
        try str.appendSlice(" ");
        try str.appendSlice(try getGqlFromSelectionSet(operationDefinition.selectionSet, allocator));

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
            try str.appendSlice(try getGqlFromDirectiveList(scalarTypeDefinition.directives, allocator));
        }
        return str.toOwnedSlice();
    }

    fn getGqlFomFragmentDefinition(fragmentDefinition: FragmentDefinition, allocator: Allocator) ![]u8 {
        var str = std.ArrayList(u8).init(allocator);
        try str.appendSlice("fragment ");
        try str.appendSlice(fragmentDefinition.name);
        try str.appendSlice(" on ");
        try str.appendSlice(try getGqlFromType(fragmentDefinition.typeCondition, allocator));
        if (fragmentDefinition.directives.len > 0) {
            try str.appendSlice(try getGqlFromDirectiveList(fragmentDefinition.directives, allocator));
        }
        try str.appendSlice(try getGqlFromSelectionSet(fragmentDefinition.selectionSet, allocator));
        return str.toOwnedSlice();
    }

    fn getGqlFomDirective(_: Directive, allocator: Allocator) ![]u8 {
        return try getNotImplementedString(allocator);
    }

    fn getGqlFomArgument(_: Argument, allocator: Allocator) ![]u8 {
        return try getNotImplementedString(allocator);
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
                try str.appendSlice(try getGqlFromInputValueDefinition(argument, allocator));
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
        try str.appendSlice(try getGqlFromType(variableDefinition.type, allocator));
        if (variableDefinition.defaultValue) |defaultValue| {
            try str.appendSlice(" = ");
            try str.appendSlice(try getGqlInputValue(defaultValue, allocator));
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
                try str.appendSlice(try getGqlFromType(listType.elementType.*, allocator));
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
                        try str.appendSlice(try getGqlFromType(listType.elementType.*, allocator));
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
                    try str.appendSlice(try getGqlInputValue(item, allocator));
                }
                try str.appendSlice("]");
            },
            .object_value => |objectValue| {
                try str.appendSlice("{");
                for (objectValue.fields, 0..) |field, i| {
                    if (i > 0) try str.appendSlice(", ");
                    try str.appendSlice(field.name);
                    try str.appendSlice(": ");
                    try str.appendSlice(try getGqlInputValue(field.value, allocator));
                }
                try str.appendSlice("}");
            },
            .boolean_value => |booleanValue| {
                try str.appendSlice(if (booleanValue.value) "true" else "false");
            },
            .int_value => |intValue| {
                try str.appendSlice(try std.fmt.allocPrint(allocator, "{d}", .{intValue.value}));
            },
            .float_value => |floatValue| {
                try str.appendSlice(try std.fmt.allocPrint(allocator, "{d}", .{floatValue.value}));
            },
            .string_value => |stringValue| {
                try str.appendSlice(try std.fmt.allocPrint(allocator, "{s}", .{stringValue.value}));
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
        try str.appendSlice(directive.name);
        if (directive.arguments.len > 0) {
            try str.appendSlice("(");
            for (directive.arguments, 0..) |argument, i| {
                if (i > 0) try str.appendSlice(", ");
                try str.appendSlice(try getGqlFromArgument(argument, allocator));
            }
            try str.appendSlice(")");
        }
        return str.toOwnedSlice();
    }

    fn getGqlFromArgument(argument: Argument, allocator: Allocator) ![]u8 {
        var str = std.ArrayList(u8).init(allocator);
        try str.appendSlice(argument.name);
        try str.appendSlice(": ");
        try str.appendSlice(try getGqlInputValue(argument.value, allocator));
        return str.toOwnedSlice();
    }

    fn getGqlFromSelectionSet(selectionSet: SelectionSet, allocator: Allocator) ![]u8 {
        var str = std.ArrayList(u8).init(allocator);
        try str.appendSlice("{");

        for (selectionSet.selections, 0..) |selection, i| {
            if (i > 0) try str.appendSlice(" ");
            switch (selection) {
                .field => |field| {
                    try str.appendSlice(try getGqlFromField(field, allocator));
                },
                .fragmentSpread => |fragmentSpread| {
                    try str.appendSlice("...");
                    try str.appendSlice(fragmentSpread.name);
                    if (fragmentSpread.directives.len > 0) {
                        try str.appendSlice(try getGqlFromDirectiveList(fragmentSpread.directives, allocator));
                    }
                },
                .inlineFragment => |inlineFragment| {
                    try str.appendSlice("... on ");
                    try str.appendSlice(inlineFragment.typeCondition);
                    try str.appendSlice(try getGqlFromSelectionSet(inlineFragment.selectionSet, allocator));
                    if (inlineFragment.directives.len > 0) {
                        try str.appendSlice(try getGqlFromDirectiveList(inlineFragment.directives, allocator));
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
                try str.appendSlice(try getGqlFromArgument(argument, allocator));
            }
            try str.appendSlice(")");
        }
        if (field.directives.len > 0) {
            try str.appendSlice(try getGqlFromDirectiveList(field.directives, allocator));
        }
        return str.toOwnedSlice();
    }

    fn getGqlFromDirectiveList(directives: []Directive, allocator: Allocator) ![]u8 {
        var str = std.ArrayList(u8).init(allocator);
        try str.appendSlice(" @");
        for (directives, 0..) |directive, i| {
            if (i > 0) try str.appendSlice(" ");
            try str.appendSlice(try getGqlFromDirective(directive, allocator));
        }
        return str.toOwnedSlice();
    }

    fn getGqlFromImplementedInterfaces(interfaces: []Interface, allocator: Allocator) ![]u8 {
        var str = std.ArrayList(u8).init(allocator);
        try str.appendSlice(" implements ");
        for (interfaces, 0..) |interface, i| {
            if (i > 0) try str.appendSlice(" & ");
            try str.appendSlice(try getGqlFromType(interface.type, allocator));
        }
        return str.toOwnedSlice();
    }

    fn getNotImplementedString(allocator: Allocator) ![]u8 {
        var str = std.ArrayList(u8).init(allocator);
        try str.appendSlice("not implemented atm");
        return str.toOwnedSlice();
    }
};
