const std = @import("std");
const lexic = @import("lexic");
const context = @import("../context.zig");
const types = @import("../types.zig");

const Token = lexic.Token;
const ParseError = types.ParseError;

/// Parse a function call starting from the opening parenthesis
/// Returns the position after the closing parenthesis, or null if parsing fails
///
/// Grammar: `( )`  (empty arguments for now)
pub fn parse_function_call(
    pos: usize,
    ctx: *const context.ParserContext,
    open_paren_token: *const Token,
) !?usize {
    var next_pos = pos;

    // For now, just parse empty argument list
    // Expect closing paren
    if (ctx.oob(next_pos)) {
        _ = try ctx.err.create_and_append_error(
            "Expected ')' after function call",
            open_paren_token.start_pos,
            open_paren_token.end_pos(),
        );
        return ParseError.Error;
    }

    const close_paren = &ctx.tokens.items[next_pos];
    if (close_paren.token_type != .RightParen) {
        _ = try ctx.err.create_and_append_error(
            "Expected ')' after function call",
            close_paren.start_pos,
            close_paren.end_pos(),
        );
        return ParseError.Error;
    }
    next_pos += 1; // consume ')'

    return next_pos;
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const error_context = @import("context");

test "should parse empty parentheses" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "()";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);
    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };

    // Get the opening paren token
    const open_paren = &tokens.items[0];
    try expectEqual(.LeftParen, open_paren.token_type);

    // Parse starting after the opening paren (pos 1)
    const next_pos = try parse_function_call(1, &parser_context, open_paren) orelse {
        try expect(false);
        return;
    };

    // Should consume the closing paren and return position 2
    try expectEqual(2, next_pos);
    try expectEqual(0, err_ctx.errors.items.len);
}

test "should fail on missing closing paren at EOF" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "(";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);
    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };

    // Get the opening paren token
    const open_paren = &tokens.items[0];

    // Parse starting after the opening paren (pos 1, which is EOF)
    const result = parse_function_call(1, &parser_context, open_paren);

    // Should return an error
    try std.testing.expectError(ParseError.Error, result);

    // Should have created an error message
    try expect(err_ctx.errors.items.len > 0);
}

test "should fail on missing closing paren with other tokens" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "( +";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);
    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };

    // Get the opening paren token
    const open_paren = &tokens.items[0];

    // Parse starting after the opening paren (pos 1, which is '+')
    const result = parse_function_call(1, &parser_context, open_paren);

    // Should return an error
    try std.testing.expectError(ParseError.Error, result);

    // Should have created an error message
    try expect(err_ctx.errors.items.len > 0);
}

test "should parse empty parens in a longer token stream" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "foo ( ) bar";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);
    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };

    // Tokens: "foo"(0), "("(1), ")"(2), "bar"(3)
    const open_paren = &tokens.items[1];
    try expectEqual(.LeftParen, open_paren.token_type);

    // Parse starting after the opening paren (pos 2)
    const next_pos = try parse_function_call(2, &parser_context, open_paren) orelse {
        try expect(false);
        return;
    };

    // Should consume the closing paren and return position 3 (pointing to "bar")
    try expectEqual(3, next_pos);
    try expectEqual(0, err_ctx.errors.items.len);
}
