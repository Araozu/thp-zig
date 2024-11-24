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

    // there should be at least 2 characters
    if (start + 1 >= cap) {
        return null;
    }

    if (input[start] == '/' and input[start + 1] == '/') {
        var current_pos = start + 2;

        // consume all bytes until newline (LF)
        while (current_pos < cap and input[current_pos] != '\n') {
            // check for CR, and throw error
            if (input[current_pos] == '\r') {
                return LexError.CRLF;
            }
            current_pos += 1;
        }

        return .{ Token.init(input[start..current_pos], TokenType.Comment, start), current_pos };
    } else {
        return null;
    }
}

test "should lex comment until EOF" {
    const input = "// aea";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("// aea", t.value);
        try std.testing.expectEqual(6, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex comment until newline (LF)" {
    const input = "// my comment\n// other comment";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("// my comment", t.value);
        try std.testing.expectEqual(13, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "shouldn lex incomplete comment" {
    const input = "/aa";
    const output = try lex(input, 0);
    try std.testing.expect(output == null);
}

test "should fail on CRLF" {
    const input = "// my comment\x0D\x0A// other comment";
    _ = lex(input, 0) catch |err| {
        try std.testing.expectEqual(LexError.CRLF, err);
        return;
    };
    try std.testing.expect(false);
}
