const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

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
        comment,
        eof,
    };

    const Location = struct {
        start: usize,
        end: usize,
    };

    pub fn toString(self: *const Token) []const u8 {
        return switch (self.tag) {
            Tag.identifier => "identifier",
            Tag.at_identifier => "@ identifier",
            Tag.string_literal => "string literal",
            Tag.integer_literal => "integer literal",
            Tag.float_literal => "float literal",
            Tag.l_parenthesis => "left parenthesis",
            Tag.r_parenthesis => "right parenthesis",
            Tag.l_brace => "left brace",
            Tag.r_brace => "right brace",
            Tag.l_bracket => "left bracket",
            Tag.r_bracket => "right bracket",
            Tag.colon => "colon",
            Tag.comment => "comment",
            Tag.eof => "<eof>",
        };
    }
};

pub const Tokenizer = struct {
    buffer: [:0]const u8,
    index: usize,

    const State = enum {
        starting,
        reading_identifier,
        reading_at_identifier,
        reading_comment,
        reading_string_literal,
        reading_number_literal,
    };

    pub fn init(
        buffer: [:0]const u8,
    ) Tokenizer {
        return Tokenizer{
            .buffer = buffer,
            // Skip the UTF-8 BOM if present
            .index = if (std.mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else 0,
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

        state: switch (State.starting) {
            State.starting => {
                switch (self.buffer[self.index]) {
                    'a'...'z', 'A'...'Z' => {
                        token.loc.start = self.index;
                        self.index += 1;
                        continue :state State.reading_identifier;
                    },
                    '@' => {
                        token.loc.start = self.index;
                        self.index += 1;
                        continue :state State.reading_at_identifier;
                    },
                    '#' => {
                        token.loc.start = self.index;
                        self.index += 1;
                        continue :state State.reading_comment;
                    },
                    '"' => {
                        token.loc.start = self.index;
                        self.index += 1;
                        continue :state State.reading_string_literal;
                    },
                    '0'...'9' => {
                        token.loc.start = self.index;
                        self.index += 1;
                        continue :state State.reading_number_literal;
                    },
                    0 => {
                        token.loc.start = self.index;
                        token.tag = Token.Tag.eof;
                        token.loc.end = self.index;
                        return token;
                    },
                    ' ', '\t', '\n', '\r' => {
                        self.index += 1;
                        continue :state State.starting;
                    },
                    '(', ')', '{', '}', '[', ']', ':' => |rune| {
                        token.loc.start = self.index;
                        token.tag = switch (rune) {
                            '(' => Token.Tag.l_parenthesis,
                            ')' => Token.Tag.r_parenthesis,
                            '{' => Token.Tag.l_brace,
                            '}' => Token.Tag.r_brace,
                            '[' => Token.Tag.l_bracket,
                            ']' => Token.Tag.r_bracket,
                            ':' => Token.Tag.colon,
                            else => unreachable,
                        };
                        self.index += 1;
                        token.loc.end = self.index;
                        return token;
                    },
                    else => {
                        std.debug.print("Unexpected rune: {c}\n", .{self.buffer[self.index]});
                        unreachable;
                    },
                }
            },
            State.reading_identifier, State.reading_at_identifier => |id| {
                while (self.buffer[self.index] >= 'a' and self.buffer[self.index] <= 'z' or
                    self.buffer[self.index] >= 'A' and self.buffer[self.index] <= 'Z' or
                    self.buffer[self.index] >= '0' and self.buffer[self.index] <= '9' or
                    self.buffer[self.index] == '_')
                {
                    self.index += 1;
                }
                token.tag = switch (id) {
                    State.reading_identifier => Token.Tag.identifier,
                    State.reading_at_identifier => Token.Tag.at_identifier,
                    else => unreachable,
                };
                token.loc.end = self.index;
                return token;
            },
            State.reading_comment => {
                while (self.buffer[self.index] != '\n') {
                    self.index += 1;
                }
                token.tag = Token.Tag.comment;
                token.loc.end = self.index;
                return token;
            },
            State.reading_string_literal => {
                var isEscapingNextRune = false;
                const isMultiLineBlock = self.buffer[self.index] == '"' and self.buffer[self.index + 1] == '"';
                if (isMultiLineBlock) {
                    self.index += 2; // skip next 2 `""`
                    while ((self.buffer[self.index] != '"' or self.buffer[self.index + 1] != '"' or self.buffer[self.index + 2] != '"') or isEscapingNextRune) {
                        isEscapingNextRune = if (self.buffer[self.index] == '\\' and !isEscapingNextRune) true else false;
                        self.index += 1;
                    }
                    self.index += 3; // skip the last 3 `"""`
                } else {
                    while (self.buffer[self.index] != '"' or isEscapingNextRune) {
                        isEscapingNextRune = if (self.buffer[self.index] == '\\' and !isEscapingNextRune) true else false;
                        self.index += 1;
                    }
                    self.index += 1;
                }

                token.tag = Token.Tag.string_literal;
                token.loc.end = self.index;
                return token;
            },
            State.reading_number_literal => {
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

    pub fn getAllTokens(self: *Tokenizer, allocator: Allocator) ![]Token {
        var tokensList = ArrayList(Token).init(allocator);
        defer tokensList.deinit();

        var currentToken = self.getNextToken();
        while (currentToken.tag != Token.Tag.eof) : (currentToken = self.getNextToken()) {
            try tokensList.append(currentToken);
        }

        return tokensList.toOwnedSlice();
    }
};

test "identifier" {
    const source = "schema";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.identifier,
    };
    try testTokenize(source, &expected_token_tags);
}

test "at identifier" {
    const source = "@something";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.at_identifier,
    };
    try testTokenize(source, &expected_token_tags);
}

test "comment" {
    const source = "# this is a comment\n";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.comment,
    };
    try testTokenize(source, &expected_token_tags);
}

test "string literal" {
    const source = "\"some \\\"string\\\"\"";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.string_literal,
    };
    try testTokenize(source, &expected_token_tags);
}

test "block string literal singleline" {
    const source = "\"\"\"FFGGHH\"\"\"";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.string_literal,
    };
    try testTokenize(source, &expected_token_tags);
}

test "block string literal multiline" {
    const source =
        \\"""
        \\weshqqq
        \\"""
    ;
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.string_literal,
    };
    try testTokenize(source, &expected_token_tags);
}

test "left parenthesis" {
    const source = "(";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.l_parenthesis,
    };
    try testTokenize(source, &expected_token_tags);
}

test "right parenthesis" {
    const source = ")";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.r_parenthesis,
    };
    try testTokenize(source, &expected_token_tags);
}

test "left brace" {
    const source = "{";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.l_brace,
    };
    try testTokenize(source, &expected_token_tags);
}

test "right brace" {
    const source = "}";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.r_brace,
    };
    try testTokenize(source, &expected_token_tags);
}

test "left bracket" {
    const source = "[";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.l_bracket,
    };
    try testTokenize(source, &expected_token_tags);
}

test "right bracket" {
    const source = "]";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.r_bracket,
    };
    try testTokenize(source, &expected_token_tags);
}

test "integer" {
    const source = "12";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.integer_literal,
    };
    try testTokenize(source, &expected_token_tags);
}

test "float" {
    const source = "12.34";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.float_literal,
    };
    try testTokenize(source, &expected_token_tags);
}

// test "kitchen sink tokens" {
//     const source = " [oui] {\"some \\\"string\\\"\" (12 12.543) }";
//     const expected_token_tags = [_]Token.Tag{
//         Token.Tag.l_bracket,
//         Token.Tag.identifier,
//         Token.Tag.r_bracket,
//         Token.Tag.l_brace,
//         Token.Tag.string_literal,
//         Token.Tag.l_parenthesis,
//         Token.Tag.integer_literal,
//         Token.Tag.float_literal,
//         Token.Tag.r_parenthesis,
//         Token.Tag.r_brace,
//     };
//     try testTokenize(source, &expected_token_tags);
// }

// test "get all tokens" {
//     const content = "schema { query(search:\"param\" quantity:12): Query }";
//     var tokenizer = Tokenizer.init(content);
//     const tokens = try tokenizer.getAllTokens(std.testing.allocator);
//     defer std.testing.allocator.free(tokens);

//     try std.testing.expectEqual(14, tokens.len);
//     // printTokens(tokens, content);
// }

fn testTokenize(source: [:0]const u8, expected_token_tags: []const Token.Tag) !void {
    var tokenizer = Tokenizer.init(
        source,
    );
    // std.debug.print("Tokens: ", .{});
    for (expected_token_tags) |expected_token_tag| {
        const token = tokenizer.getNextToken();
        // std.debug.print("{s} ", .{source[token.loc.start..token.loc.end]});
        try std.testing.expectEqual(expected_token_tag, token.tag);
    }
    // std.debug.print("\n", .{});
    const last_token = tokenizer.getNextToken();
    try std.testing.expectEqual(Token.Tag.eof, last_token.tag);
    try std.testing.expectEqual(source.len, last_token.loc.start);
    try std.testing.expectEqual(source.len, last_token.loc.end);
}

pub fn printTokens(tokens: []Token, content: [:0]const u8) void {
    for (tokens) |t| {
        std.debug.print("Token: {s} \t ({s})\n", .{
            t.toString(),
            content[t.loc.start..t.loc.end],
        });
    }
}
