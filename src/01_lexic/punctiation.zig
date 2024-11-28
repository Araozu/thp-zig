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
