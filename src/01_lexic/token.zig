pub const TokenType = enum {
    Int,
    Float,
    Identifier,
    Operator,
};

pub const Token = struct {
    value: []const u8,
    token_type: TokenType,
    start_pos: usize,

    pub fn init(value: []const u8, token_type: TokenType, start: usize) Token {
        return Token{
            .value = value,
            .token_type = token_type,
            .start_pos = start,
        };
    }
};

pub const LexError = error{
    LeadingZero,
    Incomplete,
    IncompleteFloatingNumber,
    IncompleteScientificNumber,
};

/// Contains the lexed token and the next position
/// from which the next lex should start.
pub const LexReturn = struct { Token, usize };
