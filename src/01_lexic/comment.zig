const std = @import("std");
const assert = std.debug.assert;
const token = @import("./token.zig");
const utils = @import("./utils.zig");
const errors = @import("errors");
const context = @import("context");

const Token = token.Token;
const TokenType = token.TokenType;
const LexError = token.LexError;
const LexReturn = token.LexReturn;

pub fn lex(
    input: []const u8,
    start: usize,
    ctx: *context.CompilerContext,
) LexError!?LexReturn {
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
                var err = try ctx.create_and_append_error("Usage of CRLF", current_pos, current_pos + 1);
                var label = ctx.create_error_label("There is a line feed (CR) here", current_pos, current_pos + 1);
                try err.add_label(&label);
                err.set_help("All THP code must use LF newline delimiters.");

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
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "// aea";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("// aea", t.value);
        try std.testing.expectEqual(6, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex comment until newline (LF)" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "// my comment\n// other comment";
    const output = try lex(input, 0, &ctx);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("// my comment", t.value);
        try std.testing.expectEqual(13, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "shouldn lex incomplete comment" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "/aa";
    const output = try lex(input, 0, &ctx);
    try std.testing.expect(output == null);
}

test "should fail on CRLF" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "// my comment\x0D\x0A// other comment";
    _ = lex(input, 0, &ctx) catch |err| {
        try std.testing.expectEqual(LexError.CRLF, err);
        return;
    };
    try std.testing.expect(false);
}
