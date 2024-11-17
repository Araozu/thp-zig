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
                // Continue
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

    // There should be at least 1 valid digit
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

/// Attempts to lex an integer number.
///
/// This function also attempts to lex a floating point number.
/// If it succeedes, it returns a floating point token.
/// Otherwise, it only returns an integer token.
///
/// An integer cannot have a leading zero. That is an error to
/// avoid confussion with PHP literal octals.
/// Floating point numbers can.
fn integer(input: []const u8, cap: usize, start: usize) LexError!?LexReturn {
    const first_char = input[start];
    if (!is_decimal_digit(first_char)) {
        return null;
    }

    var last_pos = start + 1;
    while (last_pos < cap and is_decimal_digit(input[last_pos])) {
        last_pos += 1;
    }

    // up to here an integer was lexed.
    // now check if a floating point number can be lexed

    // if we hit eof, return the current integer
    if (last_pos >= cap) {
        // leading zero on an integer, throw an error
        if (first_char == '0') {
            return LexError.LeadingZero;
        }

        return .{
            Token.init(input[start..last_pos], TokenType.Int, start),
            last_pos,
        };
    }

    const next_char = input[last_pos];

    return switch (next_char) {
        // if a dot is found, lex a fp number
        '.' => {
            return floating_point(input, cap, start, last_pos);
        },
        // if an `e` (exponential notiation) is found, lex that
        'e' => {
            return null;
        },
        // otherwise return the current integer
        else => {
            // leading zero on an integer, throw an error
            if (first_char == '0') {
                return LexError.LeadingZero;
            }

            return .{
                Token.init(input[start..last_pos], TokenType.Int, start),
                last_pos,
            };
        },
    };
}

/// Trailing periods are an error.
///
/// token_start: the position the current token started at
/// decimal_point: the position of the decimal point `.`
fn floating_point(input: []const u8, cap: usize, token_start: usize, decimal_point: usize) LexError!?LexReturn {
    var current_pos = decimal_point + 1;

    // there should be at least 1 digit after the period
    if (current_pos >= cap or !utils.is_decimal_digit(input[current_pos])) {
        // This is an error
        return LexError.IncompleteFloatingNumber;
    }

    // lex all remaining digits
    current_pos += 1;
    while (current_pos < cap and utils.is_decimal_digit(input[current_pos])) {
        current_pos += 1;
    }

    // return the matched fp number
    return .{
        Token.init(input[token_start..current_pos], TokenType.Float, token_start),
        current_pos,
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

test "should fail on integer with leading zero" {
    const input = "0322";
    const result = lex(input, input.len, 0) catch |err| {
        try std.testing.expect(err == token.LexError.LeadingZero);
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

test "should lex fp number 1" {
    const input = "1.2";
    const result = try lex(input, input.len, 0);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("1.2", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex fp number 2" {
    const input = "0.1";
    const result = try lex(input, input.len, 0);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("0.1", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex fp number 3" {
    const input = "123.456";
    const result = try lex(input, input.len, 0);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("123.456", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should fail on incomplete fp number" {
    const input = "123.";
    const result = lex(input, input.len, 0) catch |err| {
        try std.testing.expect(err == token.LexError.IncompleteFloatingNumber);
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
