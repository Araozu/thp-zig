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

// ===================================================================
// Common string cases
// ===================================================================

test "should lex string with multiple characters" {
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

test "should lex string with numbers" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test123\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"test123\"", t.value);
        try std.testing.expectEqual(9, tuple[1]);
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

test "should lex string with spaces and tabs" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"  \t  test  \t  \"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"  \t  test  \t  \"", t.value);
        try std.testing.expectEqual(16, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with mixed unicode and ASCII" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello 世界 world\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"hello 世界 world\"", t.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with multiple emoji" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"🚀🎉🌟\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"🚀🎉🌟\"", t.value);
    } else {
        try std.testing.expect(false);
    }
}

// ===================================================================
// Newline handling tests (strings cannot contain newlines)
// ===================================================================

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

test "should fail on newline at end before closing quote" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test\n\"";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail on carriage return newline sequence" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test\r\n\"";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        return;
    };

    try std.testing.expect(false);
}

// ===================================================================
// Edge cases
// ===================================================================

test "should lex very long string" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const long_content = "a" ** 1000;
    const input = "\"" ++ long_content ++ "\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqual(1002, t.value.len);
        try std.testing.expectEqual(1002, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with only spaces" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"     \"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"     \"", t.value);
        try std.testing.expectEqual(7, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with single quote inside" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"it's working\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"it's working\"", t.value);
        try std.testing.expectEqual(14, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string starting at non-zero position" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "abc \"test\" xyz";
    const output = try lex(input, 4, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"test\"", t.value);
        try std.testing.expectEqual(10, tuple[1]);
        try std.testing.expectEqual(4, t.start_pos);
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

// ===================================================================
// Escape character tests
// ===================================================================

test "should lex string with escaped newline sequence" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test\\nstring\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"test\\nstring\"", t.value);
        try std.testing.expectEqual(14, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with escaped tab" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test\\tstring\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"test\\tstring\"", t.value);
        try std.testing.expectEqual(14, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with escaped carriage return" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test\\rstring\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"test\\rstring\"", t.value);
        try std.testing.expectEqual(14, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with multiple consecutive backslashes" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test\\\\\\\\string\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"test\\\\\\\\string\"", t.value);
        try std.testing.expectEqual(16, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with escaped single quote" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test\\'string\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"test\\'string\"", t.value);
        try std.testing.expectEqual(14, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with multiple different escape sequences" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"line1\\nline2\\ttab\\rreturn\\\\backslash\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"line1\\nline2\\ttab\\rreturn\\\\backslash\"", t.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with escaped quote at beginning" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"\\\"start\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"\\\"start\"", t.value);
        try std.testing.expectEqual(9, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with escaped quote at end" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"end\\\"\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"end\\\"\"", t.value);
        try std.testing.expectEqual(7, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with backslash before non-escape character" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test\\x string\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"test\\x string\"", t.value);
        try std.testing.expectEqual(15, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex string with backslash before number" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"test\\0string\"";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("\"test\\0string\"", t.value);
        try std.testing.expectEqual(14, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex empty string with escaped quote in middle position" {
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

// ===================================================================
// Error message tests
// ===================================================================

test "error message: should contain correct reason for EOF" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items.len);
        try std.testing.expectEqualStrings("Incomplete String", ctx.errors.items[0].reason);
        return;
    };

    try std.testing.expect(false);
}

test "error message: should have correct position for EOF error" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items.len);
        // Error should be at position 6 (length of input)
        try std.testing.expectEqual(@as(usize, 6), ctx.errors.items[0].start_position);
        try std.testing.expectEqual(@as(usize, 7), ctx.errors.items[0].end_position);
        return;
    };

    try std.testing.expect(false);
}

test "error message: should contain label for EOF error" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items.len);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items[0].labels.items.len);
        try std.testing.expectEqualStrings("Found EOF here", ctx.errors.items[0].labels.items[0].message.static);
        return;
    };

    try std.testing.expect(false);
}

test "error message: should contain help text for EOF error" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items.len);
        try std.testing.expectEqualStrings("Strings must always end on the same line that they start.", ctx.errors.items[0].help.?);
        return;
    };

    try std.testing.expect(false);
}

test "error message: should contain correct reason for newline" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\n";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items.len);
        try std.testing.expectEqualStrings("Incomplete String", ctx.errors.items[0].reason);
        return;
    };

    try std.testing.expect(false);
}

test "error message: should have correct position for newline error" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\n";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items.len);
        // Error should be at position 6 (where newline is)
        try std.testing.expectEqual(@as(usize, 6), ctx.errors.items[0].start_position);
        try std.testing.expectEqual(@as(usize, 7), ctx.errors.items[0].end_position);
        return;
    };

    try std.testing.expect(false);
}

test "error message: should contain label for newline error" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello\n";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items.len);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items[0].labels.items.len);
        try std.testing.expectEqualStrings("Found a new line here", ctx.errors.items[0].labels.items[0].message.static);
        return;
    };

    try std.testing.expect(false);
}

test "error message: should have correct position for backslash before EOF" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello \\";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items.len);
        // Error should be at position 7 (where backslash is)
        try std.testing.expectEqual(@as(usize, 7), ctx.errors.items[0].start_position);
        try std.testing.expectEqual(@as(usize, 8), ctx.errors.items[0].end_position);
        return;
    };

    try std.testing.expect(false);
}

test "error message: should contain label for backslash before EOF" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello \\";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items.len);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items[0].labels.items.len);
        try std.testing.expectEqualStrings("Found EOF here", ctx.errors.items[0].labels.items[0].message.static);
        return;
    };

    try std.testing.expect(false);
}

test "error message: should have correct position for backslash before newline" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello \\\n";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items.len);
        // Error should be at position 7 (where backslash is)
        try std.testing.expectEqual(@as(usize, 7), ctx.errors.items[0].start_position);
        try std.testing.expectEqual(@as(usize, 8), ctx.errors.items[0].end_position);
        return;
    };

    try std.testing.expect(false);
}

test "error message: should contain label for backslash before newline" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "\"hello \\\n";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.IncompleteString, err);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items.len);
        try std.testing.expectEqual(@as(usize, 1), ctx.errors.items[0].labels.items.len);
        try std.testing.expectEqualStrings("Found a new line here", ctx.errors.items[0].labels.items[0].message.static);
        return;
    };

    try std.testing.expect(false);
}
