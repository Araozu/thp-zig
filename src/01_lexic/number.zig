const std = @import("std");
const token = @import("./token.zig");
const utils = @import("./utils.zig");

const Token = token.Token;
const TokenType = token.TokenType;

const is_decimal_digit = utils.is_decimal_digit;

fn integer(input: []const u8, cap: usize, start: usize) !?Token {
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

test "number lexer" {
    const input = "322   ";
    const result = try integer(input, input.len, 0);

    if (result) |r| {
        try std.testing.expectEqualDeep("322", r.value);
    } else {
        try std.testing.expect(false);
    }
}
