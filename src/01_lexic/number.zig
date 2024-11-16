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
            'x', 'X' => return prefixed('x', input, cap, start),
            'o', 'O' => return prefixed('o', input, cap, start),
            'b', 'B' => return prefixed('b', input, cap, start),
            else => {
                // Leading zero found. Throw an error.
                return LexError.LeadingZero;
            },
        }
    }

    // Attempt to lex an integer.
    // Floating point numbers are lexed through the int lexer
    return integer(input, cap, start);
}

/// comptime function for lexing hex, octal and binary numbers.
/// only allowed values for `prefix` are `x`, `o` & `b`.
/// An adequate validator is choosen based on `prefix`,
/// that validator will decide which characters to lex.
fn prefixed(comptime prefix: u8, input: []const u8, cap: usize, start: usize) !?LexReturn {
    const validator = switch (prefix) {
        'x' => utils.is_hex_digit,
        'o' => utils.is_octal_digit,
        'b' => utils.is_binary_digit,
        else => @compileError("Invalid prefix passed to `prefixed` function."),
    };

    var end_position = start + 2;

    // There should be at least 1 hex digit
    if (end_position >= cap or !validator(input[end_position])) {
        return LexError.Incomplete;
    }

    // loop through all chars
    end_position += 1;
    while (end_position < cap and validator(input[end_position])) {
        end_position += 1;
    }

    return .{
        Token.init(input[start..end_position], TokenType.Int, start),
        end_position,
    };
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

test "should lex octal number" {
    const input = "0o755";
    const result = try lex(input, input.len, 0);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("0o755", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex octal number 2" {
    const input = "  0o755  ";
    const result = try lex(input, input.len, 2);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("0o755", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "shouldnt parse incomplete octal number" {
    const input = "0o8";
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

test "should lex binary number" {
    const input = "0b1011";
    const result = try lex(input, input.len, 0);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("0b1011", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "shouldnt parse incomplete binary number" {
    const input = "0b2";
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
