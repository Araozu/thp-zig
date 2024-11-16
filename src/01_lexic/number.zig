const std = @import("std");
const token = @import("./token.zig");
const utils = @import("./utils.zig");

const Token = token.Token;
const TokenType = token.TokenType;

const is_decimal_digit = utils.is_decimal_digit;

const LexReturn = struct { Token, usize };

/// Attempts to lex a number, as per the language grammar.
///
/// A number is either an Int or a Float.
/// No number can have a leading zero. That is an error to
/// avoid confussion with PHP literal octals.
fn lex(input: []const u8, cap: usize, start: usize) !?LexReturn {
    const first_char = input[start];

    // Attempt to lex a hex, octal or binary number
    if (first_char == '0' and cap > start + 1) {
        const second_char = input[start + 1];
        switch (second_char) {
            'x', 'X' => return hex(),
            'o', 'O' => return octal(),
            'b', 'B' => return binary(),
        }

        // Leading zero found. Throw an error.
        // TODO: throw an error :c
    }

    // Attempt to lex an integer.
    // Floating point numbers are lexed through the int lexer
    return integer(input, cap, start);
}

fn hex() !?LexReturn {
    return null;
}

fn octal() !?LexReturn {
    return null;
}

fn binary() !?LexReturn {
    return null;
}

/// Attempts to lex an integer number.
///
/// This function fails if the first digit it encounters is a `0`,
/// this is because it could cause confusion with PHP literal integers,
/// where a number that starts with a `0` is octal, not decimal.
///
/// For this reason, this function should be called after the lexers
/// for hex, octal and binary have been called.
fn integer(input: []const u8, cap: usize, start: usize) !?LexReturn {
    const first_char = input[start];
    if (!is_decimal_digit(first_char)) {
        return null;
    }

    var last_pos = start + 1;
    while (last_pos < cap and is_decimal_digit(input[last_pos])) {
        last_pos += 1;
    }

    return .{
        Token.init(input[start..last_pos], TokenType.Int, start),
        last_pos,
    };
}

test "int lexer 1" {
    const input = "322   ";
    const result = try integer(input, input.len, 0);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("322", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "int lexer 2" {
    const input = "   644   ";
    const result = try integer(input, input.len, 3);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("644", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "int lexer 3" {
    const input = "4";
    const result = try integer(input, input.len, 0);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("4", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should return null if not an integer" {
    const input = "prosor prosor";
    const result = try integer(input, input.len, 0);

    try std.testing.expect(result == null);
}
