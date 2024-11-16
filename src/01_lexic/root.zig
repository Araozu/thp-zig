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
    const input_len = input.len;
    const next_token = try number(input, input_len, 0);
    _ = next_token;

    std.debug.print("tokenize :D {s}\n", .{input});
}

fn number(input: []const u8, cap: usize, start: usize) !?Token {
    const first_char = input[start];
    if (!is_decimal_digit(first_char)) {
        return null;
    }

    var last_pos = start + 1;
    while (last_pos < cap and is_decimal_digit(input[last_pos])) {
        last_pos += 1;
    }

    return Token.init(input[start..last_pos], TokenType.Int, start);
}

fn is_decimal_digit(c: u8) bool {
    return '0' <= c and c <= '9';
}

test "number lexer" {
    const input = "322   ";
    const result = try number(input, input.len, 0);

    if (result) |r| {
        try std.testing.expectEqualDeep("322", r.value);
    } else {
        try std.testing.expect(false);
    }
}
