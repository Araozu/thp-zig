const std = @import("std");
const assert = std.debug.assert;
const token = @import("./token.zig");
const utils = @import("./utils.zig");

const Token = token.Token;
const TokenType = token.TokenType;
const LexError = token.LexError;
const LexReturn = token.LexReturn;

pub fn lex(input: []const u8, start: usize) LexError!?LexReturn {
    // there should be at least 1 char
    assert(start < input.len);

    const c = input[start];
    const token_type = switch (c) {
        ',' => TokenType.Comma,
        '\n' => TokenType.Newline,
        else => {
            return null;
        },
    };

    return .{ Token.init(input[start .. start + 1], token_type, start), start + 1 };
}

test "shouldnt lex other things" {
    const input = "322";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

test "should lex comma" {
    const input = ",";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex new line" {
    const input = "\n";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\n", t.value);
        try std.testing.expectEqual(TokenType.Newline, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Edge Case Tests - Positioning
// ============================================================================

test "should lex comma at start of input" {
    const input = ",abc";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(@as(usize, 0), t.start_pos);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex comma at end of input" {
    const input = "abc,";
    const output = try lex(input, 3);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(@as(usize, 3), t.start_pos);
        try std.testing.expectEqual(4, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex comma in middle of input" {
    const input = "a,b";
    const output = try lex(input, 1);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(@as(usize, 1), t.start_pos);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex newline at start of input" {
    const input = "\nabc";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\n", t.value);
        try std.testing.expectEqual(TokenType.Newline, t.token_type);
        try std.testing.expectEqual(@as(usize, 0), t.start_pos);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex newline at end of input" {
    const input = "abc\n";
    const output = try lex(input, 3);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\n", t.value);
        try std.testing.expectEqual(TokenType.Newline, t.token_type);
        try std.testing.expectEqual(@as(usize, 3), t.start_pos);
        try std.testing.expectEqual(4, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex newline in middle of input" {
    const input = "a\nb";
    const output = try lex(input, 1);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\n", t.value);
        try std.testing.expectEqual(TokenType.Newline, t.token_type);
        try std.testing.expectEqual(@as(usize, 1), t.start_pos);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Edge Case Tests - Consecutive Punctuation
// ============================================================================

test "should lex first of consecutive commas" {
    const input = ",,";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex second of consecutive commas" {
    const input = ",,";
    const output = try lex(input, 1);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex first of consecutive newlines" {
    const input = "\n\n";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\n", t.value);
        try std.testing.expectEqual(TokenType.Newline, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex second of consecutive newlines" {
    const input = "\n\n";
    const output = try lex(input, 1);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\n", t.value);
        try std.testing.expectEqual(TokenType.Newline, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex comma followed by newline" {
    const input = ",\n";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex newline followed by comma" {
    const input = "\n,";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\n", t.value);
        try std.testing.expectEqual(TokenType.Newline, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Edge Case Tests - With Whitespace
// ============================================================================

test "should lex comma after space" {
    const input = " ,";
    const output = try lex(input, 1);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(@as(usize, 1), t.start_pos);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex comma before space" {
    const input = ", ";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex comma surrounded by spaces" {
    const input = " , ";
    const output = try lex(input, 1);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(@as(usize, 1), t.start_pos);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex newline after tab" {
    const input = "\t\n";
    const output = try lex(input, 1);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\n", t.value);
        try std.testing.expectEqual(TokenType.Newline, t.token_type);
        try std.testing.expectEqual(@as(usize, 1), t.start_pos);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Edge Case Tests - Mixed with Other Tokens
// ============================================================================

test "should lex comma after identifier" {
    const input = "var,";
    const output = try lex(input, 3);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(4, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex comma before identifier" {
    const input = ",var";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex comma after number" {
    const input = "123,";
    const output = try lex(input, 3);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(4, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex comma before number" {
    const input = ",456";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex newline after identifier" {
    const input = "var\n";
    const output = try lex(input, 3);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\n", t.value);
        try std.testing.expectEqual(TokenType.Newline, t.token_type);
        try std.testing.expectEqual(4, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex newline before identifier" {
    const input = "\nvar";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\n", t.value);
        try std.testing.expectEqual(TokenType.Newline, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Negative Tests - Non-punctuation
// ============================================================================

test "should not lex letter" {
    const input = "a";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

test "should not lex digit" {
    const input = "5";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

test "should not lex operator" {
    const input = "+";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

test "should not lex grouping sign paren" {
    const input = "(";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

test "should not lex grouping sign bracket" {
    const input = "[";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

test "should not lex grouping sign brace" {
    const input = "{";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

test "should not lex space" {
    const input = " ";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

test "should not lex tab" {
    const input = "\t";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

test "should not lex carriage return" {
    const input = "\r";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

// ============================================================================
// Edge Case Tests - Complex Patterns
// ============================================================================

test "should lex many commas in sequence" {
    const input = ",,,,,";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex many newlines in sequence" {
    const input = "\n\n\n\n\n";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\n", t.value);
        try std.testing.expectEqual(TokenType.Newline, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex comma at last position" {
    const input = ",";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(",", t.value);
        try std.testing.expectEqual(TokenType.Comma, t.token_type);
        try std.testing.expectEqual(@as(usize, 0), t.start_pos);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex newline at last position" {
    const input = "\n";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\n", t.value);
        try std.testing.expectEqual(TokenType.Newline, t.token_type);
        try std.testing.expectEqual(@as(usize, 0), t.start_pos);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}
