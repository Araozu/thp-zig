const std = @import("std");
const assert = std.debug.assert;
const token = @import("./token.zig");
const utils = @import("./utils.zig");

const Token = token.Token;
const TokenType = token.TokenType;
const LexError = token.LexError;
const LexReturn = token.LexReturn;

// lex an operator
pub fn lex(input: []const u8, start: usize) LexError!?LexReturn {
    const cap = input.len;
    assert(start < cap);

    // lex operator
    if (utils.lex_many_1(utils.is_operator_char, input, start)) |final_pos| {
        return .{
            Token.init(input[start..final_pos], TokenType.Operator, start),
            final_pos,
        };
    }
    // no operator found
    else {
        return null;
    }
}

test "should lex single operator" {
    const input = "=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("=", t.value);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex operator of len 2" {
    const input = "+=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("+=", t.value);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex operator of len 3" {
    const input = " >>= ";
    const output = try lex(input, 1);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(">>=", t.value);
        try std.testing.expectEqual(4, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should not lex something else" {
    const input = "322";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}
