const std = @import("std");
const assert = std.debug.assert;
const token = @import("./token.zig");
const utils = @import("./utils.zig");
const context = @import("context");

const Token = token.Token;
const TokenType = token.TokenType;
const LexError = token.LexError;
const LexReturn = token.LexReturn;

const is_decimal_digit = utils.is_decimal_digit;

/// Attempts to lex a number, as per the language grammar.
///
/// A number is either an Int or a Float.
pub fn lex(
    input: []const u8,
    cap: usize,
    start: usize,
    ctx: *context.CompilerContext,
) LexError!?LexReturn {
    assert(start < cap);
    const first_char = input[start];

    // Attempt to lex a hex, octal or binary number
    if (first_char == '0' and cap > start + 1) {
        const second_char = input[start + 1];
        switch (second_char) {
            'x', 'X' => return prefixed('x', input, cap, start, ctx),
            'o', 'O' => return prefixed('o', input, cap, start, ctx),
            'b', 'B' => return prefixed('b', input, cap, start, ctx),
            else => {
                // Continue
            },
        }
    }

    // Attempt to lex an integer.
    // Floating point numbers are lexed through the int lexer
    return integer(input, cap, start, ctx);
}

/// comptime function for lexing hex, octal and binary numbers.
/// only allowed values for `prefix` are `x`, `o` & `b`.
/// An adequate validator is choosen based on `prefix`,
/// that validator will decide which characters to lex.
fn prefixed(
    comptime prefix: u8,
    input: []const u8,
    cap: usize,
    start: usize,
    ctx: *context.CompilerContext,
) !?LexReturn {
    const validator = switch (prefix) {
        'x' => utils.is_hex_digit,
        'o' => utils.is_octal_digit,
        'b' => utils.is_binary_digit,
        else => @compileError("Invalid prefix passed to `prefixed` function."),
    };

    var end_position = start + 2;

    // There should be at least 1 valid digit
    if (end_position >= cap or !validator(input[end_position])) {
        // populate error information
        var new_error = try ctx.create_and_append_error("Incomplete number", start, end_position);
        try new_error.add_label(ctx.create_error_label("Expected a valid digit after the '" ++ [_]u8{prefix} ++ "'", start, end_position));

        switch (prefix) {
            'x' => new_error.set_help("Hex numbers should have at least one 0-9a-fA-F after the x"),
            'o' => new_error.set_help("Octal numbers should have at least one 0-7 after the o"),
            'b' => new_error.set_help("Binary numbers should have at least one 0-1 after the b"),
            else => @compileError("Invalid prefix passed to `prefixed` function."),
        }

        // throw error
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
fn integer(
    input: []const u8,
    cap: usize,
    start: usize,
    ctx: *context.CompilerContext,
) LexError!?LexReturn {
    assert(start < cap);
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
        // if there is a leading zero, two possibilities:
        // - a number with a leading zero. throw an error
        // - a single zero. valid
        if (first_char == '0' and last_pos > start + 1) {
            var err = try ctx.create_and_append_error("Leading zero", start, start + 1);
            try err.add_label(ctx.create_error_label("This decimal number has a leading zero.", start, last_pos));
            err.set_help("If you want an octal number use '0o', otherwise remove the leading zero");

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
            return floating_point(input, cap, start, last_pos, ctx);
        },
        // if an `e` (exponential notiation) is found, lex that
        'e' => {
            return scientific(input, cap, start, last_pos, ctx);
        },
        // otherwise return the current integer
        else => {
            // leading zero on an integer, throw an error
            if (first_char == '0') {
                var err = try ctx.create_and_append_error("Leading zero", start, start + 1);
                try err.add_label(ctx.create_error_label("This decimal number has a leading zero.", start, last_pos));
                err.set_help("If you want an octal number use '0o', otherwise remove the leading zero");

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
fn floating_point(
    input: []const u8,
    cap: usize,
    token_start: usize,
    period_pos: usize,
    ctx: *context.CompilerContext,
) LexError!?LexReturn {
    var current_pos = period_pos + 1;

    // there should be at least 1 digit after the period
    if (current_pos >= cap or !utils.is_decimal_digit(input[current_pos])) {
        // This is an error
        var err = try ctx.create_and_append_error("Incomplete floating point number", token_start, current_pos);
        try err.add_label(ctx.create_error_label("This number is incomplete", token_start, current_pos));
        err.set_help("Add a number after the period");

        return LexError.IncompleteFloatingNumber;
    }

    // lex all remaining digits
    current_pos += 1;
    while (current_pos < cap and utils.is_decimal_digit(input[current_pos])) {
        current_pos += 1;
    }

    // check if the current character is a `e`,
    // if so lex a scientific number
    if (current_pos < cap and input[current_pos] == 'e') {
        return scientific(input, cap, token_start, current_pos, ctx);
    }

    // return the matched fp number
    return .{
        Token.init(input[token_start..current_pos], TokenType.Float, token_start),
        current_pos,
    };
}

/// exp_pos is the position at the `e` character
fn scientific(
    input: []const u8,
    cap: usize,
    token_start: usize,
    exp_pos: usize,
    ctx: *context.CompilerContext,
) LexError!?LexReturn {
    var current_pos = exp_pos + 1;

    // expect `+` or `-`
    if (current_pos >= cap) {
        var err = try ctx.create_and_append_error("Incomplete scientific point number", token_start, current_pos);
        try err.add_label(ctx.create_error_label("Expected a '+' or '-' after the exponent", token_start, current_pos));
        err.set_help("Add a sign and a digit to complete the scientific number");

        return LexError.IncompleteScientificNumber;
    }
    const sign_char = input[current_pos];
    if (sign_char != '+' and sign_char != '-') {
        var err = try ctx.create_and_append_error("Incomplete scientific point number", current_pos, current_pos + 1);
        try err.add_label(ctx.create_error_label("Expected a '+' or '-' here, found another char", current_pos, current_pos + 1));
        err.set_help("Add a sign and a digit after the first 'e' to complete the scientific number");

        return LexError.IncompleteScientificNumber;
    }
    current_pos += 1;
    const digits_start = current_pos;

    // lex at least 1 digit
    while (current_pos < cap and utils.is_decimal_digit(input[current_pos])) {
        current_pos += 1;
    }

    // if there is no difference, no extra digits were lexed.
    if (digits_start == current_pos) {
        var err = try ctx.create_and_append_error("Incomplete scientific point number", current_pos - 1, current_pos);
        try err.add_label(ctx.create_error_label("Expected at least one digit after this sign", current_pos - 1, current_pos));
        err.set_help("Add a digit after the sign to complit the scientific number");

        return LexError.IncompleteScientificNumber;
    }

    // return the scientific number
    return .{
        Token.init(input[token_start..current_pos], TokenType.Float, token_start),
        current_pos,
    };
}

test "int lexer 1" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "322   ";
    const result = try integer(input, input.len, 0, &ctx);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("322", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "int lexer 2" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "   644   ";
    const result = try integer(input, input.len, 3, &ctx);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("644", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "int lexer 3" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "4";
    const result = try integer(input, input.len, 0, &ctx);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("4", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "int lexer 4: should lex a single zero" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "0";
    const result = try integer(input, input.len, 0, &ctx);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualStrings("0", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should return null if not an integer" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "prosor prosor";
    const result = try integer(input, input.len, 0, &ctx);

    try std.testing.expect(result == null);
}

test "should lex hex number" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "0xa";
    const result = try lex(input, input.len, 0, &ctx);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("0xa", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should fail on integer with leading zero" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "0322";
    const result = lex(input, input.len, 0, &ctx) catch |err| {
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
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "  0Xff00AA  ";
    const result = try lex(input, input.len, 2, &ctx);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("0Xff00AA", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "shouldnt parse incomplete hex number" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "0xZZ";
    const result = lex(input, input.len, 0, &ctx) catch |err| {
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
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "0x";
    const result = lex(input, input.len, 0, &ctx) catch |err| {
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
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "0o755";
    const result = try lex(input, input.len, 0, &ctx);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("0o755", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex octal number 2" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "  0o755  ";
    const result = try lex(input, input.len, 2, &ctx);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("0o755", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "shouldnt parse incomplete octal number" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "0o8";
    const result = lex(input, input.len, 0, &ctx) catch |err| {
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
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "0b1011";
    const result = try lex(input, input.len, 0, &ctx);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("0b1011", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "shouldnt parse incomplete binary number" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "0b2";
    const result = lex(input, input.len, 0, &ctx) catch |err| {
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
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "1.2";
    const result = try lex(input, input.len, 0, &ctx);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("1.2", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex fp number 2" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "0.1";
    const result = try lex(input, input.len, 0, &ctx);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("0.1", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex fp number 3" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "123.456";
    const result = try lex(input, input.len, 0, &ctx);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("123.456", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should fail on incomplete fp number" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "123.";
    const result = lex(input, input.len, 0, &ctx) catch |err| {
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

test "should lex scientific number" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "42e+3";
    const result = try lex(input, input.len, 0, &ctx);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("42e+3", r.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should fail on incomplete scientific number" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "123e";
    const result = lex(input, input.len, 0, &ctx) catch |err| {
        try std.testing.expect(err == token.LexError.IncompleteScientificNumber);
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

test "should fail on incomplete scientific number 2" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "123e+";
    const result = lex(input, input.len, 0, &ctx) catch |err| {
        try std.testing.expect(err == token.LexError.IncompleteScientificNumber);
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

test "should lex floating scientific number" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "0.58e+3";
    const result = try lex(input, input.len, 0, &ctx);

    if (result) |tuple| {
        const r = tuple[0];
        try std.testing.expectEqualDeep("0.58e+3", r.value);
    } else {
        try std.testing.expect(false);
    }
}
