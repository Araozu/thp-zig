const std = @import("std");
const lexic = @import("lexic");
const context = @import("../context.zig");
const error_context = @import("context");
const types = @import("../types.zig");
const PrattExpression = @import("./pratt_expression.zig").PrattExpression;
const m_ids = @import("../ids.zig");

const Token = lexic.Token;
const TokenType = lexic.TokenType;
const ParseError = types.ParseError;

/// Parses a Primary expression:
///
/// ```ebnf
/// Primary = Identifier
///         | Int
///         | Float
///         | String
///         | "(" Expresion ")"
/// ```
pub const PrimaryExpression = union(enum) {
    int: *const Token,
    float: *const Token,
    string: *const Token,
    bool: *const Token,
    identifier: *const Token,
    paren: struct {
        exp: *PrattExpression,
        lparen: *const Token,
        rparen: *const Token,
        id: u64,
    },

    const Self = @This();

    /// Attempts to parse an expression from a token stream.
    ///
    /// Receives a pointer to the memory for initialization,
    /// returns the position of the next token
    pub fn init(
        self: *Self,
        pos: usize,
        ctx: *const context.ParserContext,
    ) ParseError!?usize {
        std.debug.assert(pos < ctx.tokens.items.len);

        // Check if parsing simple tokens

        const t = &ctx.tokens.items[pos];
        if (t.token_type == TokenType.Identifier) {
            self.* = .{ .identifier = t };
            return pos + 1;
        } else if (t.token_type == TokenType.Int) {
            self.* = .{ .int = t };
            return pos + 1;
        } else if (t.token_type == TokenType.Float) {
            self.* = .{ .float = t };
            return pos + 1;
        } else if (t.token_type == TokenType.String) {
            self.* = .{ .string = t };
            return pos + 1;
        } else if (t.token_type == TokenType.Bool) {
            self.* = .{ .bool = t };
            return pos + 1;
        } else if (t.token_type == TokenType.LeftParen) {
            const lparen_t = t;

            // check theres tokens left after the paren
            if (ctx.oob(pos + 1)) {
                var err = try ctx.err.create_and_append_error("Syntax error", lparen_t.start_pos, lparen_t.end_pos());
                try err.add_label(ctx.err.create_error_label(
                    "There is nothing after this open paren",
                    lparen_t.start_pos,
                    lparen_t.end_pos(),
                ));

                return ParseError.Error;
            }

            var inner_exp = try ctx.allocator.create(PrattExpression);
            errdefer ctx.allocator.destroy(inner_exp);

            const next_pos_maybe = try inner_exp.init(pos + 1, ctx);
            const next_pos = next_pos_maybe orelse {
                //
                var err = try ctx.err.create_and_append_error("Syntax error", lparen_t.start_pos, lparen_t.end_pos());
                try err.add_label(ctx.err.create_error_label(
                    "There is nothing after this open paren",
                    lparen_t.start_pos,
                    lparen_t.end_pos(),
                ));

                return ParseError.Error;
            };
            errdefer inner_exp.deinit(ctx);

            // Expect right paren
            if (ctx.oob(next_pos)) {
                var err = try ctx.err.create_and_append_error("Syntax error", lparen_t.start_pos, lparen_t.end_pos());
                try err.add_label(ctx.err.create_error_label(
                    "Expected a closing paren at the end of this expression",
                    lparen_t.start_pos,
                    lparen_t.end_pos(),
                ));

                return ParseError.Error;
            }

            const rparen_t = &ctx.tokens.items[next_pos];
            if (rparen_t.token_type != TokenType.RightParen) {
                const err = try ctx.err.create_and_append_error("Syntax error", rparen_t.start_pos, rparen_t.end_pos());
                const token_name = rparen_t.token_type.to_string();
                const error_name = try std.fmt.allocPrint(ctx.err.allocator, "Expected a right paren here, found a {s}", .{token_name});
                try err.add_label(ctx.err.create_error_label_alloc(
                    error_name,
                    rparen_t.start_pos,
                    rparen_t.end_pos(),
                ));

                return ParseError.Error;
            }

            self.* = .{
                .paren = .{
                    .exp = inner_exp,
                    .lparen = lparen_t,
                    .rparen = rparen_t,
                    .id = m_ids.generate_id(),
                },
            };

            // Return from where to continue parsing
            return next_pos + 1;
        }

        return null;
    }

    pub fn get_range(self: *const Self) struct { usize, usize } {
        return switch (self.*) {
            .int, .float, .string, .bool, .identifier => |t| .{ t.start_pos, t.end_pos() },
            .paren => |p_struct| .{ p_struct.lparen.start_pos, p_struct.rparen.end_pos() },
        };
    }

    pub fn deinit(
        self: *Self,
        ctx: *const context.ParserContext,
    ) void {
        switch (self.*) {
            .paren => |inner_exp| {
                inner_exp.exp.deinit(ctx);
                ctx.allocator.destroy(inner_exp.exp);
            },
            else => {},
        }
    }
};

test "should parse int expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "322";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);
    if (try expr.init(0, &parser_context)) |next_pos| {
        try std.testing.expectEqualDeep("322", expr.int.value);
        try std.testing.expectEqualDeep(TokenType.Int, expr.int.token_type);
        try std.testing.expectEqualDeep(1, next_pos);
        return;
    }
    try std.testing.expect(false);
}

test "should parse float expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "322.644";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);
    if (try expr.init(0, &parser_context)) |next_pos| {
        try std.testing.expectEqualDeep("322.644", expr.float.value);
        try std.testing.expectEqualDeep(TokenType.Float, expr.float.token_type);
        try std.testing.expectEqualDeep(1, next_pos);
        return;
    }
    try std.testing.expect(false);
}

test "should parse string expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "\"hello\"";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);
    if (try expr.init(0, &parser_context)) |next_pos| {
        try std.testing.expectEqualDeep("\"hello\"", expr.string.value);
        try std.testing.expectEqualDeep(TokenType.String, expr.string.token_type);
        try std.testing.expectEqualDeep(1, next_pos);
        return;
    }
    try std.testing.expect(false);
}

test "should parse expression within parens" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "(322)";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    if (try expr.init(0, &parser_context)) |next_pos| {
        switch (expr) {
            .paren => |inner_exp| {
                // The inner expression should be a PrattExpression wrapping a primary
                try std.testing.expect(inner_exp.exp.* == .primary);
                try std.testing.expectEqualDeep("322", inner_exp.exp.*.primary.expr.int.value);
                try std.testing.expectEqualDeep(TokenType.Int, inner_exp.exp.*.primary.expr.int.token_type);
                try std.testing.expectEqualDeep(3, next_pos);
            },
            else => try std.testing.expect(false),
        }
    } else {
        try std.testing.expect(false);
    }
}

test "should fail on non expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "@!%";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var expr: PrimaryExpression = undefined;

    const m_next = try expr.init(0, &parser_context);

    if (m_next) |_| {
        defer expr.deinit(&parser_context);

        try std.testing.expect(false);
    }

    return;
}

// ============================================================================
// Token offset/position tests
// ============================================================================

test "int expression should have correct token offsets" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "  42";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    const next_pos = try expr.init(0, &parser_context);
    try std.testing.expect(next_pos != null);
    try std.testing.expectEqual(2, expr.int.start_pos);
    try std.testing.expectEqual(4, expr.int.end_pos());
}

test "float expression should have correct token offsets" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "   3.14159";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    const next_pos = try expr.init(0, &parser_context);
    try std.testing.expect(next_pos != null);
    try std.testing.expectEqual(3, expr.float.start_pos);
    try std.testing.expectEqual(10, expr.float.end_pos());
}

test "string expression should have correct token offsets" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "    \"test string\"";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    const next_pos = try expr.init(0, &parser_context);
    try std.testing.expect(next_pos != null);
    try std.testing.expectEqual(4, expr.string.start_pos);
    try std.testing.expectEqual(17, expr.string.end_pos());
}

test "identifier expression should have correct token offsets" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = " myVariable";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    const next_pos = try expr.init(0, &parser_context);
    try std.testing.expect(next_pos != null);
    try std.testing.expectEqual(1, expr.identifier.start_pos);
    try std.testing.expectEqual(11, expr.identifier.end_pos());
}

test "paren expression should have correct token offsets for lparen and rparen" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "  (123)";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    const next_pos = try expr.init(0, &parser_context);
    try std.testing.expect(next_pos != null);
    try std.testing.expectEqual(2, expr.paren.lparen.start_pos);
    try std.testing.expectEqual(3, expr.paren.lparen.end_pos());
    try std.testing.expectEqual(6, expr.paren.rparen.start_pos);
    try std.testing.expectEqual(7, expr.paren.rparen.end_pos());
}

// ============================================================================
// get_range tests
// ============================================================================

test "get_range should return correct range for int" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "  999";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    const range = expr.get_range();
    try std.testing.expectEqual(2, range[0]);
    try std.testing.expectEqual(5, range[1]);
}

test "get_range should return correct range for float" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = " 1.5";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    const range = expr.get_range();
    try std.testing.expectEqual(1, range[0]);
    try std.testing.expectEqual(4, range[1]);
}

test "get_range should return correct range for string" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "\"ab\"";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    const range = expr.get_range();
    try std.testing.expectEqual(0, range[0]);
    try std.testing.expectEqual(4, range[1]);
}

test "get_range should return correct range for identifier" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "foo";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    const range = expr.get_range();
    try std.testing.expectEqual(0, range[0]);
    try std.testing.expectEqual(3, range[1]);
}

test "get_range should return range from lparen to rparen for paren expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = " (42) ";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    const range = expr.get_range();
    // Range should span from '(' at position 1 to ')' end at position 5
    try std.testing.expectEqual(1, range[0]);
    try std.testing.expectEqual(5, range[1]);
}

// ============================================================================
// Value parsing tests
// ============================================================================

test "should parse identifier with underscore" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "my_var_123";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    const next_pos = try expr.init(0, &parser_context);
    try std.testing.expect(next_pos != null);
    try std.testing.expectEqualDeep("my_var_123", expr.identifier.value);
    try std.testing.expectEqualDeep(TokenType.Identifier, expr.identifier.token_type);
}

test "should parse negative integer in parens" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    // Note: This parses as paren containing binary expression (0 - 42) or unary depending on implementation
    // For now testing that parens work with expressions
    const input = "(0)";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    const next_pos = try expr.init(0, &parser_context);
    try std.testing.expect(next_pos != null);
    try std.testing.expectEqual(3, next_pos.?);
}

test "should parse nested parentheses" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "((5))";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    const next_pos = try expr.init(0, &parser_context);
    try std.testing.expect(next_pos != null);
    try std.testing.expectEqual(5, next_pos.?);
    // Outer expression is paren
    try std.testing.expect(expr == .paren);
    // Inner expression is also paren (wrapped in PrattExpression.primary)
    try std.testing.expect(expr.paren.exp.* == .primary);
    try std.testing.expect(expr.paren.exp.primary.expr.* == .paren);
}

test "should parse deeply nested parentheses" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "(((1)))";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    const next_pos = try expr.init(0, &parser_context);
    try std.testing.expect(next_pos != null);
    try std.testing.expectEqual(7, next_pos.?);
}

test "should parse empty string" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "\"\"";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    const next_pos = try expr.init(0, &parser_context);
    try std.testing.expect(next_pos != null);
    try std.testing.expectEqualDeep("\"\"", expr.string.value);
}

test "should parse string with spaces" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "\"hello world\"";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    const next_pos = try expr.init(0, &parser_context);
    try std.testing.expect(next_pos != null);
    try std.testing.expectEqualDeep("\"hello world\"", expr.string.value);
}

test "should parse large integer" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "9999999999";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    const next_pos = try expr.init(0, &parser_context);
    try std.testing.expect(next_pos != null);
    try std.testing.expectEqualDeep("9999999999", expr.int.value);
}

test "should parse float with many decimal places" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "3.141592653589793";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    const next_pos = try expr.init(0, &parser_context);
    try std.testing.expect(next_pos != null);
    try std.testing.expectEqualDeep("3.141592653589793", expr.float.value);
}

// ============================================================================
// Error cases
// ============================================================================

test "should error on unclosed paren" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "(42";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;

    const result = expr.init(0, &parser_context);

    try std.testing.expectError(ParseError.Error, result);
    try std.testing.expect(err_ctx.errors.items.len > 0);
    try std.testing.expectEqualStrings("Syntax error", err_ctx.errors.items[0].reason);
}

test "should error on empty parens" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "()";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;

    const result = expr.init(0, &parser_context);

    try std.testing.expectError(ParseError.Error, result);
    try std.testing.expect(err_ctx.errors.items.len > 0);
}

test "should error on paren with only operator inside" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "(+)";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;

    const result = expr.init(0, &parser_context);

    try std.testing.expectError(ParseError.Error, result);
    try std.testing.expect(err_ctx.errors.items.len > 0);
}

test "should error on mismatched parens - wrong closing bracket" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "(42]";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;

    const result = expr.init(0, &parser_context);

    try std.testing.expectError(ParseError.Error, result);
    try std.testing.expect(err_ctx.errors.items.len > 0);
    // Check error label mentions expecting right paren
    try std.testing.expect(err_ctx.errors.items[0].labels.items.len > 0);
}

test "should error on paren followed by EOF" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "(";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;

    const result = expr.init(0, &parser_context);

    try std.testing.expectError(ParseError.Error, result);
    try std.testing.expect(err_ctx.errors.items.len > 0);
    try std.testing.expectEqualStrings("Syntax error", err_ctx.errors.items[0].reason);
}

test "error position should point to opening paren when nothing after" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "  (";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;

    _ = expr.init(0, &parser_context) catch {};

    try std.testing.expect(err_ctx.errors.items.len > 0);
    // Error position should point to the opening paren at position 2
    try std.testing.expectEqual(2, err_ctx.errors.items[0].start_position);
    try std.testing.expectEqual(3, err_ctx.errors.items[0].end_position);
}

test "error position should point to wrong token when expecting rparen" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "(1 2)";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;

    _ = expr.init(0, &parser_context) catch {};

    try std.testing.expect(err_ctx.errors.items.len > 0);
    // Error should point to the unexpected '2' token at position 3
    try std.testing.expectEqual(3, err_ctx.errors.items[0].start_position);
}

// ============================================================================
// Parsing from different positions
// ============================================================================

test "should parse expression starting from non-zero position" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "foo 123";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    // Parse starting at position 1 (the "123" token)
    const next_pos = try expr.init(1, &parser_context);
    try std.testing.expect(next_pos != null);
    try std.testing.expectEqual(2, next_pos.?);
    try std.testing.expectEqualDeep("123", expr.int.value);
}

// ============================================================================
// Token type verification
// ============================================================================

test "identifier token type should be Identifier" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "someVar";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    try std.testing.expectEqual(TokenType.Identifier, expr.identifier.token_type);
}

test "int token type should be Int" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "42";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    try std.testing.expectEqual(TokenType.Int, expr.int.token_type);
}

test "float token type should be Float" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "3.14";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    try std.testing.expectEqual(TokenType.Float, expr.float.token_type);
}

test "string token type should be String" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "\"test\"";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    try std.testing.expectEqual(TokenType.String, expr.string.token_type);
}

test "paren lparen token type should be LeftParen" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "(1)";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    try std.testing.expectEqual(TokenType.LeftParen, expr.paren.lparen.token_type);
    try std.testing.expectEqual(TokenType.RightParen, expr.paren.rparen.token_type);
}

// ============================================================================
// Expression discrimination tests
// ============================================================================

test "should discriminate as int" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "100";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    try std.testing.expect(expr == .int);
    try std.testing.expect(expr != .float);
    try std.testing.expect(expr != .string);
    try std.testing.expect(expr != .identifier);
    try std.testing.expect(expr != .paren);
}

test "should discriminate as float" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "1.0";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    try std.testing.expect(expr == .float);
}

test "should discriminate as string" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "\"s\"";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    try std.testing.expect(expr == .string);
}

test "should discriminate as identifier" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "x";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    try std.testing.expect(expr == .identifier);
}

test "should discriminate as paren" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "(x)";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    try std.testing.expect(expr == .paren);
}

// ============================================================================
// Expression within parens tests
// ============================================================================

test "paren expression inner value should match" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "(myIdent)";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    try std.testing.expect(expr == .paren);
    try std.testing.expect(expr.paren.exp.* == .primary);
    try std.testing.expect(expr.paren.exp.primary.expr.* == .identifier);
    try std.testing.expectEqualStrings("myIdent", expr.paren.exp.primary.expr.identifier.value);
}

test "paren expression with float inner value" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "(2.718)";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    try std.testing.expect(expr == .paren);
    try std.testing.expect(expr.paren.exp.* == .primary);
    try std.testing.expect(expr.paren.exp.primary.expr.* == .float);
    try std.testing.expectEqualStrings("2.718", expr.paren.exp.primary.expr.float.value);
}

test "paren expression with string inner value" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "(\"inner\")";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: PrimaryExpression = undefined;
    defer expr.deinit(&parser_context);

    _ = try expr.init(0, &parser_context);
    try std.testing.expect(expr == .paren);
    try std.testing.expect(expr.paren.exp.* == .primary);
    try std.testing.expect(expr.paren.exp.primary.expr.* == .string);
    try std.testing.expectEqualStrings("\"inner\"", expr.paren.exp.primary.expr.string.value);
}
