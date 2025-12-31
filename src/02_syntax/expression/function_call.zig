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
        try arguments.append(ctx.allocator, expr);

        // Consume trailing comma if exists
        if (!ctx.oob(next_pos) and ctx.tokens.items[next_pos].token_type == .Comma) {
            next_pos += 1;
        }
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

test "should parse a function called with an expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "print(1 + 2)";
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

    // Should consume the closing paren and return position 6
    try expectEqual(6, next_pos);
    try expectEqual(0, err_ctx.errors.items.len);
}

// ============================================================================
// Token offset/position tests
// ============================================================================

test "error position should point to open paren when closing paren missing at EOF" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "  (";
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

    const open_paren = &tokens.items[0];
    _ = parse_function_call(1, &parser_context, open_paren, &arguments) catch {};

    try expect(err_ctx.errors.items.len > 0);
    // Error should point to the opening paren at position 2
    try expectEqual(2, err_ctx.errors.items[0].start_position);
    try expectEqual(3, err_ctx.errors.items[0].end_position);
}

test "error position should point to wrong token when expecting closing paren" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "foo(42 ]";
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
    _ = parse_function_call(2, &parser_context, open_paren, &arguments) catch {};

    try expect(err_ctx.errors.items.len > 0);
    // Error should point to the ']' token at position 7
    try expectEqual(7, err_ctx.errors.items[0].start_position);
    try expectEqual(8, err_ctx.errors.items[0].end_position);
}

// ============================================================================
// Argument count tests
// ============================================================================

test "empty parens should have zero arguments" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn()";
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
    _ = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    try expectEqual(0, arguments.items.len);
}

test "single argument should have one argument" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(123)";
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
    _ = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    try expectEqual(1, arguments.items.len);
}

test "single argument with trailing comma should have one argument" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(123,)";
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
    _ = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    try expectEqual(1, arguments.items.len);
}

// ============================================================================
// Argument value tests
// ============================================================================

test "argument value should be integer literal" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(999)";
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
    _ = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    try expectEqual(1, arguments.items.len);
    try expect(arguments.items[0].* == .primary);
    try expect(arguments.items[0].primary.expr.* == .int);
    try std.testing.expectEqualStrings("999", arguments.items[0].primary.expr.int.value);
}

test "argument value should be float literal" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(3.14)";
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
    _ = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    try expectEqual(1, arguments.items.len);
    try expect(arguments.items[0].* == .primary);
    try expect(arguments.items[0].primary.expr.* == .float);
    try std.testing.expectEqualStrings("3.14", arguments.items[0].primary.expr.float.value);
}

test "argument value should be string literal" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(\"hello\")";
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
    _ = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    try expectEqual(1, arguments.items.len);
    try expect(arguments.items[0].* == .primary);
    try expect(arguments.items[0].primary.expr.* == .string);
    try std.testing.expectEqualStrings("\"hello\"", arguments.items[0].primary.string.value);
}

test "argument value should be identifier" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(myVar)";
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
    _ = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    try expectEqual(1, arguments.items.len);
    try expect(arguments.items[0].* == .primary);
    try expect(arguments.items[0].primary.expr.* == .identifier);
    try std.testing.expectEqualStrings("myVar", arguments.items[0].primary.expr.identifier.value);
}

test "argument should be binary expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(1 + 2)";
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
    _ = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    try expectEqual(1, arguments.items.len);
    try expect(arguments.items[0].* == .binary);
    try std.testing.expectEqualStrings("+", arguments.items[0].binary.operator.value);
}

test "argument should be parenthesized expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn((42))";
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
    _ = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    try expectEqual(1, arguments.items.len);
    try expect(arguments.items[0].* == .primary);
    try expect(arguments.items[0].primary.expr.* == .paren);
}

// ============================================================================
// Error cases
// ============================================================================

test "should error on wrong closing bracket type" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(42]";
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
    const result = parse_function_call(2, &parser_context, open_paren, &arguments);

    try std.testing.expectError(ParseError.Error, result);
    try expect(err_ctx.errors.items.len > 0);
    try std.testing.expectEqualStrings("Expected ')' after function call", err_ctx.errors.items[0].reason);
}

test "should error on wrong closing brace type" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(42}";
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
    const result = parse_function_call(2, &parser_context, open_paren, &arguments);

    try std.testing.expectError(ParseError.Error, result);
    try expect(err_ctx.errors.items.len > 0);
    try std.testing.expectEqualStrings("Expected ')' after function call", err_ctx.errors.items[0].reason);
}

test "should error when argument followed by identifier instead of comma or paren" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(42 bar)";
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
    const result = parse_function_call(2, &parser_context, open_paren, &arguments);

    try std.testing.expectError(ParseError.Error, result);
    try expect(err_ctx.errors.items.len > 0);
}

test "error message should be correct for EOF after argument" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(42";
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
    const result = parse_function_call(2, &parser_context, open_paren, &arguments);

    try std.testing.expectError(ParseError.Error, result);
    try expect(err_ctx.errors.items.len > 0);
    try std.testing.expectEqualStrings("Expected ')' after function call", err_ctx.errors.items[0].reason);
}

test "error message should be correct for EOF after trailing comma" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(42,";
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
    const result = parse_function_call(2, &parser_context, open_paren, &arguments);

    try std.testing.expectError(ParseError.Error, result);
    try expect(err_ctx.errors.items.len > 0);
    try std.testing.expectEqualStrings("Expected ')' after function call", err_ctx.errors.items[0].reason);
}

// ============================================================================
// Next position tests
// ============================================================================

test "next position should be after closing paren for empty call" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn() + 1";
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
    const next_pos = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    // Tokens: fn(0) ((1) )(2) +(3) 1(4)
    // Next position should be 3 (pointing to '+')
    try expectEqual(3, next_pos);
}

test "next position should be after closing paren for call with argument" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(42) + 1";
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
    const next_pos = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    // Tokens: fn(0) ((1) 42(2) )(3) +(4) 1(5)
    // Next position should be 4 (pointing to '+')
    try expectEqual(4, next_pos);
}

test "next position should be after closing paren for call with trailing comma" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(42,) + 1";
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
    const next_pos = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    // Tokens: fn(0) ((1) 42(2) ,(3) )(4) +(5) 1(6)
    // Next position should be 5 (pointing to '+')
    try expectEqual(5, next_pos);
}

test "next position should be after closing paren for call with expression argument" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(1 + 2) - 3";
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
    const next_pos = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    // Tokens: fn(0) ((1) 1(2) +(3) 2(4) )(5) -(6) 3(7)
    // Next position should be 6 (pointing to '-')
    try expectEqual(6, next_pos);
}

// ============================================================================
// Edge cases
// ============================================================================

test "should parse function call at end of token stream" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn()";
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
    const next_pos = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    // Should return position after last token
    try expectEqual(3, next_pos);
    try expectEqual(0, err_ctx.errors.items.len);
}

test "should parse nested function call as argument" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "outer(inner())";
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
    const next_pos = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    // Tokens: outer(0) ((1) inner(2) ((3) )(4) )(5)
    try expectEqual(6, next_pos);
    try expectEqual(1, arguments.items.len);
    // The argument should be a function call
    try expect(arguments.items[0].* == .function);
}

test "argument with complex binary expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "fn(1 + 2 - 3)";
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
    const next_pos = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    // Tokens: fn(0) ((1) 1(2) +(3) 2(4) -(5) 3(6) )(7)
    try expectEqual(8, next_pos);
    try expectEqual(1, arguments.items.len);
    try expect(arguments.items[0].* == .binary);
}

test "should correctly parse when open paren has offset" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "    fn(42)";
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
    try expectEqual(6, open_paren.start_pos);
    try expectEqual(7, open_paren.end_pos());

    const next_pos = try parse_function_call(2, &parser_context, open_paren, &arguments) orelse {
        try expect(false);
        return;
    };

    try expectEqual(4, next_pos);
    try expectEqual(1, arguments.items.len);
}
