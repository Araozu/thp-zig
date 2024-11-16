const std = @import("std");
const token = @import("./token.zig");
const utils = @import("./utils.zig");

const Token = token.Token;
const TokenType = token.TokenType;
const LexError = token.LexError;

const is_decimal_digit = utils.is_decimal_digit;

const LexReturn = struct { Token, usize };

/// Attempts to lex a number, as per the language grammar.
///
/// A number is either an Int or a Float.
/// No number can have a leading zero. That is an error to
/// avoid confussion with PHP literal octals.
pub fn lex(input: []const u8, cap: usize, start: usize) LexError!?LexReturn {
    const first_char = input[start];

    // Attempt to lex a hex, octal or binary number
    if (first_char == '0' and cap > start + 1) {
        const second_char = input[start + 1];
        switch (second_char) {
            'x', 'X' => return hex(input, cap, start),
            'o', 'O' => return octal(),
            'b', 'B' => return binary(),
            else => {
                // Leading zero found. Throw an error.
                // TODO: throw an error :c
                return LexError.LeadingZero;
            },
        }
    }

    // Attempt to lex an integer.
    // Floating point numbers are lexed through the int lexer
    return integer(input, cap, start);
}

/// Lexes a hexadecimal number.
/// Allows 0-9a-fA-F
/// Assumes that `start` is the position of the initial zero
fn hex(input: []const u8, cap: usize, start: usize) LexError!?LexReturn {
    var end_position = start + 2;

    // There should be at least 1 hex digit
    if (end_position >= cap or !utils.is_hex_digit(input[end_position])) {
        return LexError.Incomplete;
    }

    // loop through all chars
    end_position += 1;

    while (end_position < cap and utils.is_hex_digit(input[end_position])) {
        end_position += 1;
    }

    return .{
        Token.init(input[start..end_position], TokenType.Int, start),
        end_position,
    };
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

test "should lex hex number" {
    const input = "0xa";
    const result = try lex(input, input.len, 0);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("0xa", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex hex number 2" {
    const input = "  0Xff00AA  ";
    const result = try lex(input, input.len, 2);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("0Xff00AA", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "shouldnt parse incomplete hex number" {
    const input = "0xZZ";
    const result = lex(input, input.len, 0) catch |err| {
        try std.testing.expect(err == token.LexError.Incomplete);
        return;
    };

    if (result) |tuple| {
        const r = tuple[0];
        std.debug.print("{s}\n", .{r.value});
    } else {
        std.debug.print("nil returned", .{});
    }

    try std.testing.expect(false);
}

test "shouldnt parse incomplete hex number 2" {
    const input = "0x";
    const result = lex(input, input.len, 0) catch |err| {
        try std.testing.expect(err == token.LexError.Incomplete);
        return;
    };

    if (result) |tuple| {
        const r = tuple[0];
        std.debug.print("{s}\n", .{r.value});
    } else {
        std.debug.print("nil returned", .{});
    }

    try std.testing.expect(false);
}
