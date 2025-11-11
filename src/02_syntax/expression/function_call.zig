const std = @import("std");
const lexic = @import("lexic");
const context = @import("../context.zig");
const types = @import("../types.zig");
const m_pratt_expression = @import("./pratt_expression.zig");

const Token = lexic.Token;
const ParseError = types.ParseError;
const PrattExpression = m_pratt_expression.PrattExpression;

/// Parse a function call starting from the opening parenthesis
/// Returns the position after the closing parenthesis, or null if parsing fails
///
/// ```ebnf
/// FunctionCall = "(" ArgumentList? ")"
/// ArgumentList = Expression (comma Expression)* comma?
/// ```
pub fn parse_function_call(
    pos: usize,
    ctx: *const context.ParserContext,
    open_paren_token: *const Token,
    arguments: *std.ArrayListUnmanaged(*PrattExpression),
) ParseError!?usize {
    var next_pos = pos;

    // Attempt to parse argument list
    args: {
        // Parse expression
        var expr = try ctx.allocator.create(PrattExpression);
        errdefer ctx.allocator.destroy(expr);

        next_pos = try expr.init(next_pos, ctx) orelse {
            // No args, continue to closing paren
            ctx.allocator.destroy(expr);
            break :args;
        };

        // Parse many: comma, expression

        // Consume trailing comma if exists
        if (ctx.tokens.items[next_pos].token_type == .Comma) {
            next_pos += 1;
        }

        try arguments.append(ctx.allocator, expr);
    }

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

    var arguments: std.ArrayListUnmanaged(*PrattExpression) = .empty;
    defer {
        for (arguments.items) |arg| {
            arg.deinit(&parser_context);
            parser_context.allocator.destroy(arg);
        }
        arguments.deinit(parser_context.allocator);
    }

    // Get the opening paren token
    const open_paren = &tokens.items[0];
    try expectEqual(.LeftParen, open_paren.token_type);

    // Parse starting after the opening paren (pos 1)
    const next_pos = try parse_function_call(1, &parser_context, open_paren, &arguments) orelse {
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

    var arguments: std.ArrayListUnmanaged(*PrattExpression) = .empty;
    defer {
        for (arguments.items) |arg| {
            arg.deinit(&parser_context);
            parser_context.allocator.destroy(arg);
        }
        arguments.deinit(parser_context.allocator);
    }

    // Get the opening paren token
    const open_paren = &tokens.items[0];

    // Parse starting after the opening paren (pos 1, which is EOF)
    const result = parse_function_call(1, &parser_context, open_paren, &arguments);

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

    var arguments: std.ArrayListUnmanaged(*PrattExpression) = .empty;
    defer {
        for (arguments.items) |arg| {
            arg.deinit(&parser_context);
            parser_context.allocator.destroy(arg);
        }
        arguments.deinit(parser_context.allocator);
    }

    // Get the opening paren token
    const open_paren = &tokens.items[0];

    // Parse starting after the opening paren (pos 1, which is '+')
    const result = parse_function_call(1, &parser_context, open_paren, &arguments);

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

    var arguments: std.ArrayListUnmanaged(*PrattExpression) = .empty;
    defer {
        for (arguments.items) |arg| {
            arg.deinit(&parser_context);
            parser_context.allocator.destroy(arg);
        }
        arguments.deinit(parser_context.allocator);
    }

    // Tokens: "foo"(0), "("(1), ")"(2), "bar"(3)
    const open_paren = &tokens.items[1];
    try expectEqual(.LeftParen, open_paren.token_type);

    // Parse starting after the opening paren (pos 2)
    const next_pos = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    // Should consume the closing paren and return position 3 (pointing to "bar")
    try expectEqual(3, next_pos);
    try expectEqual(0, err_ctx.errors.items.len);
}

test "should parse a single param" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "print(42)";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);
    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };

    var arguments: std.ArrayListUnmanaged(*PrattExpression) = .empty;
    defer {
        for (arguments.items) |arg| {
            arg.deinit(&parser_context);
            parser_context.allocator.destroy(arg);
        }
        arguments.deinit(parser_context.allocator);
    }

    const open_paren = &tokens.items[1];
    try expectEqual(.LeftParen, open_paren.token_type);

    // Parse starting after the opening paren (pos 2)
    const next_pos = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };
    try expectEqual(4, next_pos);
}

test "should parse a single param with trailing comma" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "print(42,)";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);
    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };

    var arguments: std.ArrayListUnmanaged(*PrattExpression) = .empty;
    defer {
        for (arguments.items) |arg| {
            arg.deinit(&parser_context);
            parser_context.allocator.destroy(arg);
        }
        arguments.deinit(parser_context.allocator);
    }

    const open_paren = &tokens.items[1];
    try expectEqual(.LeftParen, open_paren.token_type);

    // Parse starting after the opening paren (pos 2)
    const next_pos = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };
    try expectEqual(5, next_pos);
}
