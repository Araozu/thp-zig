const std = @import("std");
const assert = std.debug.assert;
const token = @import("./token.zig");
const utils = @import("./utils.zig");

const Token = token.Token;
const TokenType = token.TokenType;
const LexError = token.LexError;
const LexReturn = token.LexReturn;

// lex grouping signs
pub fn lex(input: []const u8, start: usize) LexError!?LexReturn {
    // there should be at least 1 char
    assert(start < input.len);

    const c = input[start];
    const token_type = switch (c) {
        '(' => TokenType.LeftParen,
        ')' => TokenType.RightParen,
        '[' => TokenType.LeftBracket,
        ']' => TokenType.RightBracket,
        '{' => TokenType.LeftBrace,
        '}' => TokenType.RightBrace,
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

test "should lex opening paren" {
    const input = "( hello )";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("(", t.value);
        try std.testing.expectEqual(TokenType.LeftParen, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex closing paren" {
    const input = "( hello )";
    const output = try lex(input, 8);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(")", t.value);
        try std.testing.expectEqual(TokenType.RightParen, t.token_type);
        try std.testing.expectEqual(9, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex opening bracket" {
    const input = "[ hello ]";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("[", t.value);
        try std.testing.expectEqual(TokenType.LeftBracket, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex closing bracket" {
    const input = "[ hello ]";
    const output = try lex(input, 8);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("]", t.value);
        try std.testing.expectEqual(TokenType.RightBracket, t.token_type);
        try std.testing.expectEqual(9, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex opening brace" {
    const input = "{ hello }";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("{", t.value);
        try std.testing.expectEqual(TokenType.LeftBrace, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex closing brace" {
    const input = "{ hello }";
    const output = try lex(input, 8);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("}", t.value);
        try std.testing.expectEqual(TokenType.RightBrace, t.token_type);
        try std.testing.expectEqual(9, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}
