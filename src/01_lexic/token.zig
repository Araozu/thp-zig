pub const TokenType = enum {
    Int,
    Float,
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
