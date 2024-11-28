const std = @import("std");
const assert = std.debug.assert;
const token = @import("./token.zig");
const utils = @import("./utils.zig");

const Token = token.Token;
const TokenType = token.TokenType;
const LexError = token.LexError;
const LexReturn = token.LexReturn;

pub fn lex(input: []const u8, start: usize) LexError!?LexReturn {
    const cap = input.len;
    assert(start < cap);

    // lex starting quote
    if (input[start] != '"') {
        return null;
    }

    // lex everything but quote and newline
    // TODO: escape characters
    var current_pos = start + 1;
    while (current_pos < cap and input[current_pos] != '"' and input[current_pos] != '\n') {
        current_pos += 1;
    }

    // expect ending quote
    if (current_pos == cap or input[current_pos] == '\n') {
        // Error: EOF before ending the string
        return LexError.IncompleteString;
    } else {
        return .{
            Token.init(input[start .. current_pos + 1], TokenType.String, start),
            current_pos + 1,
        };
    }
}

test "should lex empty string" {
    const input = "\"\"";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"\"", t.value);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with 1 char" {
    const input = "\"a\"";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"a\"", t.value);
        try std.testing.expectEqual(3, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with unicode" {
    const input = "\"😭\"";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"😭\"", t.value);
        try std.testing.expectEqual(6, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "shouldnt lex other things" {
    const input = "322";
    const output = try lex(input, 0);
    try std.testing.expect(output == null);
}

test "should fail on EOF before closing string" {
    const input = "\"hello";
    _ = lex(input, 0) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail on newline before closing string" {
    const input = "\"hello\n";
    _ = lex(input, 0) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}
