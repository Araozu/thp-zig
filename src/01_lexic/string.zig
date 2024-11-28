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

    while (current_pos < cap) {
        const next_char = input[current_pos];
        // string is finished, return it
        if (next_char == '"') {
            return .{
                Token.init(input[start .. current_pos + 1], TokenType.String, start),
                current_pos + 1,
            };
        }
        // new line, return error
        else if (next_char == '\n') {
            return LexError.IncompleteString;
        }
        // lex escape characters
        else if (next_char == '\\') {
            // if next char is EOF, return error
            if (current_pos + 1 == cap) {
                return LexError.IncompleteString;
            }
            // if next char is newline, return error
            else if (input[current_pos + 1] == '\n') {
                return LexError.IncompleteString;
            }
            // here just consume whatever char is after
            // TODO: if next char is not an escape char, return warning?
            current_pos += 2;
            continue;
        }

        current_pos += 1;
    }

    // this could only reach when EOF is hit, return error
    return LexError.IncompleteString;
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

test "should lex string with escape character 1" {
    const input = "\"test\\\"string\"";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"test\\\"string\"", t.value);
        try std.testing.expectEqual(14, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with escape character 2" {
    const input = "\"test\\\\string\"";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"test\\\\string\"", t.value);
        try std.testing.expectEqual(14, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should fail on EOF after backslash" {
    const input = "\"hello \\";
    _ = lex(input, 0) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail on newline after backslash" {
    const input = "\"hello \\\n";
    _ = lex(input, 0) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}
