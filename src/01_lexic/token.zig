pub const TokenType = enum {
    Int,
    Float,
    Identifier,
    Datatype,
    Operator,
    Comment,
    String,
    // grouping signs
    LeftParen,
    RightParen,
    LeftBracket,
    RightBracket,
    LeftBrace,
    RightBrace,
    // punctiation that carries special meaning
    Comma,
    Newline,
    // Each keyword will have its own token
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
    IncompleteString,
    CRLF,
};

/// Contains the lexed token and the next position
/// from which the next lex should start.
pub const LexReturn = struct { Token, usize };
