const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Token = struct {
    tag: Tag,
    loc: Location,
    buffer: [:0]const u8,

    pub const Tag = enum {
        identifier,
        string_literal,
        string_literal_block,
        integer_literal,
        float_literal,
        comment,
        eof,

        punct_excl,
        punct_dollar,
        punct_ampersand,
        punct_paren_left,
        punct_paren_right,
        punct_spread,
        punct_colon,
        punct_equal,
        punct_at,
        punct_bracket_left,
        punct_bracket_right,
        punct_brace_left,
        punct_pipe,
        punct_brace_right,
    };

    const Location = struct {
        start: usize,
        end: usize,
    };

    pub fn toString(self: *const Token) []const u8 {
        return switch (self.tag) {
            Tag.identifier => "identifier",
            Tag.string_literal => "string literal",
            Tag.string_literal_block => "string block literal",
            Tag.integer_literal => "integer literal",
            Tag.float_literal => "float literal",
            Tag.comment => "comment",
            Tag.eof => "<eof>",

            Tag.punct_excl => "exclamation mark",
            Tag.punct_dollar => "dollar",
            Tag.punct_ampersand => "ampersand",
            Tag.punct_paren_left => "left parenthesis",
            Tag.punct_paren_right => "right parenthesis",
            Tag.punct_spread => "spread",
            Tag.punct_colon => "colon",
            Tag.punct_equal => "equal",
            Tag.punct_at => "@",
            Tag.punct_bracket_left => "left bracket",
            Tag.punct_bracket_right => "right bracket",
            Tag.punct_brace_left => "left brace",
            Tag.punct_pipe => "pipe",
            Tag.punct_brace_right => "right brace",
        };
    }

    pub fn getStringValue(self: *const Token, allocator: Allocator) ![]const u8 {
        return allocator.dupe(u8, self.buffer[self.loc.start..self.loc.end]);
    }

    pub fn getStringRef(self: *const Token) []const u8 {
        return self.buffer[self.loc.start..self.loc.end];
    }
};

const TokenizerError = error{UnexpectedRuneError};
const Utf8Bom = "\xEF\xBB\xBF";

pub const Tokenizer = struct {
    allocator: Allocator,
    buffer: [:0]const u8,
    index: usize,
    tokensList: ArrayList(Token),

    const State = enum {
        starting,
        reading_identifier,
        reading_comment,
        reading_string_literal,
        reading_number_literal,
        reading_punct_spread,
    };

    pub fn init(
        allocator: Allocator,
        buffer: [:0]const u8,
    ) Tokenizer {
        return Tokenizer{
            .allocator = allocator,
            .buffer = buffer,
            // Skip the UTF-8 BOM if present
            .index = if (std.mem.startsWith(u8, buffer, Utf8Bom)) 3 else 0,
            .tokensList = .empty,
        };
    }

    pub fn deinit(self: *Tokenizer) void {
        self.tokensList.deinit(self.allocator);
    }

    pub fn getNextToken(self: *Tokenizer) TokenizerError!Token {
        var token = Token{
            .buffer = self.buffer,
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
                    ' ', '\t', '\n', '\r', ',' => {
                        self.index += 1;
                        continue :state State.starting;
                    },
                    '!', '$', '&', '(', ')', '.', ':', '=', '@', '[', ']', '{', '|', '}' => |rune| {
                        token.loc.start = self.index;
                        token.tag = switch (rune) {
                            '!' => Token.Tag.punct_excl,
                            '$' => Token.Tag.punct_dollar,
                            '&' => Token.Tag.punct_ampersand,
                            '(' => Token.Tag.punct_paren_left,
                            ')' => Token.Tag.punct_paren_right,
                            '.' => continue :state State.reading_punct_spread,
                            ':' => Token.Tag.punct_colon,
                            '=' => Token.Tag.punct_equal,
                            '@' => Token.Tag.punct_at,
                            '[' => Token.Tag.punct_bracket_left,
                            ']' => Token.Tag.punct_bracket_right,
                            '{' => Token.Tag.punct_brace_left,
                            '|' => Token.Tag.punct_pipe,
                            '}' => Token.Tag.punct_brace_right,
                            else => unreachable,
                        };
                        self.index += 1;
                        token.loc.end = self.index;
                        return token;
                    },
                    else => {
                        std.debug.print("Unexpected rune: {c}\n", .{self.buffer[self.index]});
                        return TokenizerError.UnexpectedRuneError;
                    },
                }
            },
            State.reading_punct_spread => {
                if (self.buffer[self.index] == '.' and self.buffer[self.index + 1] == '.' and self.buffer[self.index + 2] == '.') {
                    self.index += 3;
                    token.tag = Token.Tag.punct_spread;
                    token.loc.end = self.index;
                    return token;
                } else {
                    std.debug.print("Unexpected rune: {c}\n", .{self.buffer[self.index]});
                    return TokenizerError.UnexpectedRuneError;
                }
            },
            State.reading_identifier => {
                while (self.buffer[self.index] >= 'a' and self.buffer[self.index] <= 'z' or
                    self.buffer[self.index] >= 'A' and self.buffer[self.index] <= 'Z' or
                    self.buffer[self.index] >= '0' and self.buffer[self.index] <= '9' or
                    self.buffer[self.index] == '_')
                {
                    self.index += 1;
                }
                token.tag = Token.Tag.identifier;
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

                token.tag = if (isMultiLineBlock)
                    Token.Tag.string_literal_block
                else
                    Token.Tag.string_literal;
                token.loc.end = self.index;
                return token;
            },
            State.reading_number_literal => {
                var alreadyHadExponent = false;
                var alreadyHadDot = false;
                while (self.buffer[self.index] >= '0' and self.buffer[self.index] <= '9' or (self.buffer[self.index] == '.' or self.buffer[self.index] == 'e')) {
                    const isExponent = self.buffer[self.index] == 'e';
                    const isDot = self.buffer[self.index] == '.';
                    if (alreadyHadExponent) {
                        if (isExponent or isDot) {
                            std.debug.print("Unexpected character: {c}\n", .{self.buffer[self.index]});
                            return TokenizerError.UnexpectedRuneError;
                        }
                    }
                    if (isExponent) {
                        alreadyHadExponent = true;
                    }
                    if (isDot) {
                        alreadyHadDot = true;
                    }
                    self.index += 1;
                }
                if (alreadyHadDot or alreadyHadExponent) {
                    token.tag = Token.Tag.float_literal;
                } else {
                    token.tag = Token.Tag.integer_literal;
                }
                token.loc.end = self.index;
                return token;
            },
        }
    }

    pub fn getAllTokens(self: *Tokenizer) ![]Token {
        var currentToken = try self.getNextToken();
        while (currentToken.tag != Token.Tag.eof) : (currentToken = try self.getNextToken()) {
            if (currentToken.tag == Token.Tag.comment) continue;
            try self.tokensList.append(self.allocator, currentToken);
        }

        return self.tokensList.toOwnedSlice(self.allocator);
    }
};

test "identifier" {
    const source = "schema";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.identifier,
    };
    try testTokenize(source, &expected_token_tags);
}

test "at and identifier" {
    const source = "@something";
    const expected_token_tags = [_]Token.Tag{ Token.Tag.punct_at, Token.Tag.identifier };
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
        Token.Tag.string_literal_block,
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
        Token.Tag.string_literal_block,
    };
    try testTokenize(source, &expected_token_tags);
}

test "left parenthesis" {
    const source = "(";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.punct_paren_left,
    };
    try testTokenize(source, &expected_token_tags);
}

test "right parenthesis" {
    const source = ")";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.punct_paren_right,
    };
    try testTokenize(source, &expected_token_tags);
}

test "left brace" {
    const source = "{";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.punct_brace_left,
    };
    try testTokenize(source, &expected_token_tags);
}

test "right brace" {
    const source = "}";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.punct_brace_right,
    };
    try testTokenize(source, &expected_token_tags);
}

test "left bracket" {
    const source = "[";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.punct_bracket_left,
    };
    try testTokenize(source, &expected_token_tags);
}

test "right bracket" {
    const source = "]";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.punct_bracket_right,
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

test "float with exponent" {
    const source = "0.1234e3";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.float_literal,
    };
    try testTokenize(source, &expected_token_tags);
}

test "kitchen sink tokens" {
    const source = " [oui] {\"some \\\"string\\\"\" (12 12.543) }";
    const expected_token_tags = [_]Token.Tag{
        Token.Tag.punct_bracket_left,
        Token.Tag.identifier,
        Token.Tag.punct_bracket_right,
        Token.Tag.punct_brace_left,
        Token.Tag.string_literal,
        Token.Tag.punct_paren_left,
        Token.Tag.integer_literal,
        Token.Tag.float_literal,
        Token.Tag.punct_paren_right,
        Token.Tag.punct_brace_right,
    };
    try testTokenize(source, &expected_token_tags);
}

test "get all tokens" {
    const content = "query Test { search(terms:\"param\", quantity:12) { result {id ...someFragment }}}";
    var tokenizer = Tokenizer.init(std.testing.allocator, content);
    defer tokenizer.deinit();
    const tokens = try tokenizer.getAllTokens();
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(21, tokens.len);
}

fn testTokenize(source: [:0]const u8, expected_token_tags: []const Token.Tag) !void {
    var tokenizer = Tokenizer.init(
        std.testing.allocator,
        source,
    );
    defer tokenizer.deinit();

    for (expected_token_tags) |expected_token_tag| {
        const token = try tokenizer.getNextToken();
        try std.testing.expectEqual(expected_token_tag, token.tag);
    }

    const last_token = try tokenizer.getNextToken();
    try std.testing.expectEqual(Token.Tag.eof, last_token.tag);
    try std.testing.expectEqual(source.len, last_token.loc.start);
    try std.testing.expectEqual(source.len, last_token.loc.end);
}
