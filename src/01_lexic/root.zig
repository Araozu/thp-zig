const std = @import("std");
const t = std.testing;

const TokenType = enum {
    Int,
    Float,
};

const Token = struct {
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

pub fn tokenize(input: []const u8) !void {
    const next_token = try number(input, 0);
    _ = next_token;

    std.debug.print("tokenize :D {s}\n", .{input});
}

fn number(input: []const u8, start: usize) !?Token {
    const first_char = input[start];
    if (!is_digit(first_char)) {
        return null;
    }

    return Token.init(input[start .. start + 1], TokenType.Int, start);
}

fn is_digit(c: u8) bool {
    return '0' <= c and c <= '9';
}

test "number lexer" {
    const input = "3";
    const result = try number(input, 0);

    if (result) |r| {
        try std.testing.expectEqual("3", r.value);
    } else {
        try std.testing.expect(false);
    }
}
