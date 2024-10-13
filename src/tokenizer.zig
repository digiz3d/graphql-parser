const std = @import("std");

pub const Token = struct {
    tag: Tag,
    loc: Location,

    pub const Tag = enum {
        identifier,
        at_identifier,
        string_literal,
        integer_literal,
        float_literal,
        l_parenthesis,
        r_parenthesis,
        l_brace,
        r_brace,
        l_bracket,
        r_bracket,
        colon,
        eof,
    };

    const Location = struct {
        start: usize,
        end: usize,
    };

    pub fn toString(self: *const Token) []const u8 {
        return switch (self.tag) {
            .identifier => "identifier",
            .at_identifier => "at_identifier",
            .string_literal => "string_literal",
            .integer_literal => "integer_literal",
            .float_literal => "float_literal",
            .l_parenthesis => "l_parenthesis",
            .r_parenthesis => "r_parenthesis",
            .l_brace => "l_brace",
            .r_brace => "r_brace",
            .l_bracket => "l_bracket",
            .r_bracket => "r_bracket",
            .colon => "colon",
            .eof => "eof",
        };
    }
};

pub const Tokenizer = struct {
    buffer: [:0]const u8,
    index: usize,

    const State = enum {
        start,
        identifier,
        at_identifier,
        string_literal,
        number_literal,
    };

    pub fn init(buffer: [:0]const u8) Tokenizer {
        // Skip the UTF-8 BOM if present.
        return .{
            .buffer = buffer,
            .index = 0,
        };
    }

    pub fn getNextToken(self: *Tokenizer) Token {
        var token = Token{
            .tag = undefined,
            .loc = .{
                .start = self.index,
                .end = self.index,
            },
        };

        state: switch (State.start) {
            .start => {
                switch (self.buffer[self.index]) {
                    'a'...'z', 'A'...'Z' => {
                        token.loc.start = self.index;
                        self.index += 1;
                        continue :state .identifier;
                    },
                    '@' => {
                        token.loc.start = self.index;
                        self.index += 1;
                        continue :state .at_identifier;
                    },
                    '"' => {
                        token.loc.start = self.index;
                        self.index += 1;
                        continue :state .string_literal;
                    },
                    '0'...'9' => {
                        token.loc.start = self.index;
                        self.index += 1;
                        continue :state .number_literal;
                    },
                    0 => {
                        token.loc.start = self.index;
                        token.tag = .eof;
                        token.loc.end = self.index;
                        return token;
                    },
                    ' ', '\t', '\n', '\r' => {
                        self.index += 1;
                        continue :state .start;
                    },
                    '(', ')', '{', '}', '[', ']', ':' => |rune| {
                        token.loc.start = self.index;
                        token.tag = switch (rune) {
                            '(' => .l_parenthesis,
                            ')' => .r_parenthesis,
                            '{' => .l_brace,
                            '}' => .r_brace,
                            '[' => .l_bracket,
                            ']' => .r_bracket,
                            ':' => .colon,
                            else => unreachable,
                        };
                        self.index += 1;
                        token.loc.end = self.index;
                        return token;
                    },
                    else => {
                        std.debug.print("Unexpected character: {c}\n", .{self.buffer[self.index]});
                        unreachable;
                    },
                }
            },
            .identifier, .at_identifier => |id| {
                while (self.buffer[self.index] >= 'a' and self.buffer[self.index] <= 'z' or
                    self.buffer[self.index] >= 'A' and self.buffer[self.index] <= 'Z' or
                    self.buffer[self.index] >= '0' and self.buffer[self.index] <= '9' or
                    self.buffer[self.index] == '_')
                {
                    self.index += 1;
                }
                token.tag = switch (id) {
                    .identifier => Token.Tag.identifier,
                    .at_identifier => Token.Tag.at_identifier,
                    else => unreachable,
                };
                token.loc.end = self.index;
                return token;
            },
            .string_literal => {
                var isBlockString = false;
                var isEscapingNextChar = false;
                if (self.buffer[self.index] == '"') {
                    if (self.buffer[self.index + 1] == '"') {
                        isBlockString = true;
                    }
                }
                while (self.buffer[self.index] != '"' or isEscapingNextChar) {
                    if (self.buffer[self.index] == '\\') {
                        isEscapingNextChar = true;
                    } else {
                        isEscapingNextChar = false;
                    }
                    self.index += 1;
                }
                self.index += 1;
                token.tag = Token.Tag.string_literal;
                token.loc.end = self.index;
                return token;
            },
            .number_literal => {
                var isFloat = false;
                while (self.buffer[self.index] >= '0' and self.buffer[self.index] <= '9' or self.buffer[self.index] == '.') {
                    if (self.buffer[self.index] == '.') {
                        isFloat = true;
                    }
                    self.index += 1;
                }
                if (isFloat) {
                    token.tag = Token.Tag.float_literal;
                } else {
                    token.tag = Token.Tag.integer_literal;
                }
                token.loc.end = self.index;
                return token;
            },
        }
    }
};

test "identifier" {
    const source = "schema";
    const expected_token_tags = [_]Token.Tag{
        .identifier,
    };
    try testTokenize(source, &expected_token_tags);
}

test "at identifier" {
    const source = "@something";
    const expected_token_tags = [_]Token.Tag{
        .at_identifier,
    };
    try testTokenize(source, &expected_token_tags);
}

test "string literal" {
    const source = "\"some \\\"string\\\"\"";
    const expected_token_tags = [_]Token.Tag{
        .string_literal,
    };
    try testTokenize(source, &expected_token_tags);
}

test "left parenthesis" {
    const source = "(";
    const expected_token_tags = [_]Token.Tag{
        .l_parenthesis,
    };
    try testTokenize(source, &expected_token_tags);
}

test "right parenthesis" {
    const source = ")";
    const expected_token_tags = [_]Token.Tag{
        .r_parenthesis,
    };
    try testTokenize(source, &expected_token_tags);
}

test "left brace" {
    const source = "{";
    const expected_token_tags = [_]Token.Tag{
        .l_brace,
    };
    try testTokenize(source, &expected_token_tags);
}

test "right brace" {
    const source = "}";
    const expected_token_tags = [_]Token.Tag{
        .r_brace,
    };
    try testTokenize(source, &expected_token_tags);
}

test "left bracket" {
    const source = "[";
    const expected_token_tags = [_]Token.Tag{
        .l_bracket,
    };
    try testTokenize(source, &expected_token_tags);
}

test "right bracket" {
    const source = "]";
    const expected_token_tags = [_]Token.Tag{
        .r_bracket,
    };
    try testTokenize(source, &expected_token_tags);
}

test "integer" {
    const source = "12";
    const expected_token_tags = [_]Token.Tag{
        .integer_literal,
    };
    try testTokenize(source, &expected_token_tags);
}

test "float" {
    const source = "12.34";
    const expected_token_tags = [_]Token.Tag{
        .float_literal,
    };
    try testTokenize(source, &expected_token_tags);
}

test "kitchen sink tokens" {
    const source = " [oui] {\"some \\\"string\\\"\" (12 12.543) }";
    const expected_token_tags = [_]Token.Tag{
        .l_bracket,
        .identifier,
        .r_bracket,
        .l_brace,
        .string_literal,
        .l_parenthesis,
        .integer_literal,
        .float_literal,
        .r_parenthesis,
        .r_brace,
    };
    try testTokenize(source, &expected_token_tags);
}

fn testTokenize(source: [:0]const u8, expected_token_tags: []const Token.Tag) !void {
    var tokenizer = Tokenizer.init(source);
    for (expected_token_tags) |expected_token_tag| {
        const token = tokenizer.getNextToken();
        try std.testing.expectEqual(expected_token_tag, token.tag);
        std.debug.print("Token: {s} \n", .{source[token.loc.start..token.loc.end]});
    }
    const last_token = tokenizer.getNextToken();
    try std.testing.expectEqual(Token.Tag.eof, last_token.tag);
    try std.testing.expectEqual(source.len, last_token.loc.start);
    try std.testing.expectEqual(source.len, last_token.loc.end);
}
