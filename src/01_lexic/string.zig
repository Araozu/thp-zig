const std = @import("std");
const assert = std.debug.assert;
const token = @import("./token.zig");
const utils = @import("./utils.zig");
const context = @import("context");

const Token = token.Token;
const TokenType = token.TokenType;
const LexError = token.LexError;
const LexReturn = token.LexReturn;

pub fn lex(
    input: []const u8,
    start: usize,
    ctx: *context.ErrorContext,
) LexError!?LexReturn {
    const cap = input.len;
    assert(start < cap);

    // lex starting quote
    if (input[start] != '"') {
        return null;
    }

    // lex everything but quote and newline
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
        // new line, initialize and return error
        else if (next_char == '\n') {
            var err = try ctx.create_and_append_error("Incomplete String", current_pos, current_pos + 1);
            try err.add_label(ctx.create_error_label("Found a new line here", current_pos, current_pos + 1));
            err.set_help("Strings must always end on the same line that they start.");

            return LexError.IncompleteString;
        }
        // lex escape characters
        else if (next_char == '\\') {
            // if next char is EOF, return error
            if (current_pos + 1 == cap) {
                var err = try ctx.create_and_append_error("Incomplete String", current_pos, current_pos + 1);
                try err.add_label(ctx.create_error_label("Found EOF here", current_pos, current_pos + 1));
                err.set_help("Strings must always end on the same line that they start.");
                return LexError.IncompleteString;
            }
            // if next char is newline, return error
            else if (input[current_pos + 1] == '\n') {
                var err = try ctx.create_and_append_error("Incomplete String", current_pos, current_pos + 1);
                try err.add_label(ctx.create_error_label("Found a new line here", current_pos, current_pos + 1));
                err.set_help("Strings must always end on the same line that they start.");
                return LexError.IncompleteString;
            }
            // here just consume whatever char is after
            // TODO: if next char is not an escape char, return warning?
            current_pos += 2;
            continue;
        }

        current_pos += 1;
    }

    // this can only happen when EOF is hit, return error
    var err = try ctx.create_and_append_error("Incomplete String", current_pos, current_pos + 1);
    try err.add_label(ctx.create_error_label("Found EOF here", current_pos, current_pos + 1));
    err.set_help("Strings must always end on the same line that they start.");

    return LexError.IncompleteString;
}

test "should lex empty string" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"\"", t.value);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with 1 char" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"a\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"a\"", t.value);
        try std.testing.expectEqual(3, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with unicode" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"😭\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"😭\"", t.value);
        try std.testing.expectEqual(6, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "shouldnt lex other things" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "322";
    const output = try lex(input, 0, &ctx);
    try std.testing.expect(output == null);
}

test "should fail on EOF before closing string" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail on newline before closing string" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\n";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

test "should lex string with escape character 1" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test\\\"string\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"test\\\"string\"", t.value);
        try std.testing.expectEqual(14, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with escape character 2" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test\\\\string\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"test\\\\string\"", t.value);
        try std.testing.expectEqual(14, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should fail on EOF after backslash" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello \\";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail on newline after backslash" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello \\\n";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

// ============================================================================
// Normal cases - various string contents
// ============================================================================

test "should lex string with spaces" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello world\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"hello world\"", t.value);
        try std.testing.expectEqual(13, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with tabs" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\tworld\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"hello\tworld\"", t.value);
        try std.testing.expectEqual(13, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with numbers" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"12345\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"12345\"", t.value);
        try std.testing.expectEqual(7, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with special characters" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"!@#$%^&*()\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"!@#$%^&*()\"", t.value);
        try std.testing.expectEqual(12, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with single quotes inside" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"it's a test\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"it's a test\"", t.value);
        try std.testing.expectEqual(13, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex long string" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"this is a very long string that contains many characters and should still be lexed correctly\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(input, t.value);
        try std.testing.expectEqual(input.len, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Unicode tests
// ============================================================================

test "should lex string with multiple unicode emojis" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"🎉🎊🎁\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"🎉🎊🎁\"", t.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with chinese characters" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"你好世界\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"你好世界\"", t.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with mixed ascii and unicode" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello 世界 🌍\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"hello 世界 🌍\"", t.value);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Escape sequence tests
// ============================================================================

test "should lex string with escaped n" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\\nworld\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"hello\\nworld\"", t.value);
        try std.testing.expectEqual(14, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with escaped t" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\\tworld\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"hello\\tworld\"", t.value);
        try std.testing.expectEqual(14, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with escaped r" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\\rworld\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"hello\\rworld\"", t.value);
        try std.testing.expectEqual(14, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with multiple escape sequences" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"line1\\nline2\\tindented\\\\backslash\\\"quote\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"line1\\nline2\\tindented\\\\backslash\\\"quote\"", t.value);
        try std.testing.expectEqual(42, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string starting with escape" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"\\nhello\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"\\nhello\"", t.value);
        try std.testing.expectEqual(9, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string ending with escape before quote" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\\n\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"hello\\n\"", t.value);
        try std.testing.expectEqual(9, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with consecutive escapes" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"\\\\\\\\\""; // four backslashes: "\\\\"
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"\\\\\\\\\"", t.value);
        try std.testing.expectEqual(6, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with escaped quote at start" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"\\\"hello\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"\\\"hello\"", t.value);
        try std.testing.expectEqual(9, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with escaped quote at end" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\\\"\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"hello\\\"\"", t.value);
        try std.testing.expectEqual(9, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string that is only escaped quote" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"\\\"\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"\\\"\"", t.value);
        try std.testing.expectEqual(4, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string that is only escaped backslash" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"\\\\\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"\\\\\"", t.value);
        try std.testing.expectEqual(4, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Start position tests
// ============================================================================

test "should lex string starting at non-zero position" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "var x = \"hello\"";
    const output = try lex(input, 8, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"hello\"", t.value);
        try std.testing.expectEqual(15, tuple[1]);
        try std.testing.expectEqual(8, t.start_pos);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string in the middle of input" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "abc\"test\"xyz";
    const output = try lex(input, 3, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"test\"", t.value);
        try std.testing.expectEqual(9, tuple[1]);
        try std.testing.expectEqual(3, t.start_pos);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Non-string input tests (should return null)
// ============================================================================

test "shouldnt lex identifier" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "hello";
    const output = try lex(input, 0, &ctx);
    try std.testing.expect(output == null);
}

test "shouldnt lex single quote string" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "'hello'";
    const output = try lex(input, 0, &ctx);
    try std.testing.expect(output == null);
}

test "shouldnt lex backtick string" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "`hello`";
    const output = try lex(input, 0, &ctx);
    try std.testing.expect(output == null);
}

test "shouldnt lex when starting with space" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = " \"hello\"";
    const output = try lex(input, 0, &ctx);
    try std.testing.expect(output == null);
}

test "shouldnt lex operator" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "+";
    const output = try lex(input, 0, &ctx);
    try std.testing.expect(output == null);
}

// ============================================================================
// Error cases - incomplete strings
// ============================================================================

test "should fail on just opening quote" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail on newline immediately after opening quote" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"\n";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail on newline in middle of string" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\nworld\"";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail on carriage return newline" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\r\n";
    // Note: \r is not treated as newline, but \n is
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail on EOF with escape sequence in progress" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test\\";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail on newline after escape in middle of string" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test\\\nmore\"";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail on string with content but no closing quote" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"this string never ends";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail when string at non-zero position hits EOF" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "var x = \"incomplete";
    _ = lex(input, 8, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail when string at non-zero position hits newline" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "var x = \"incomplete\n";
    _ = lex(input, 8, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

// ============================================================================
// Edge cases
// ============================================================================

test "should lex string with only spaces" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"   \"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"   \"", t.value);
        try std.testing.expectEqual(5, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with only tabs" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"\t\t\t\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"\t\t\t\"", t.value);
        try std.testing.expectEqual(5, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string followed by more content" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\" + \"world\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"hello\"", t.value);
        try std.testing.expectEqual(7, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex second string at correct position" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\" + \"world\"";
    const output = try lex(input, 10, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"world\"", t.value);
        try std.testing.expectEqual(17, tuple[1]);
        try std.testing.expectEqual(10, t.start_pos);
    } else {
        try std.testing.expect(false);
    }
}

test "should handle string with null byte" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\x00world\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"hello\x00world\"", t.value);
        try std.testing.expectEqual(13, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should handle string with high ascii characters" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"café\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"café\"", t.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should verify token type is String" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqual(TokenType.String, t.token_type);
    } else {
        try std.testing.expect(false);
    }
}
