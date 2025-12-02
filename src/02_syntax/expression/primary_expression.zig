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
    identifier: *const Token,
    paren: struct {
        exp: *PrattExpression,
        lparen: *const Token,
        rparen: *const Token,
        id: u64,
    },

    /// Attempts to parse an expression from a token stream.
    ///
    /// Receives a pointer to the memory for initialization,
    /// returns the position of the next token
    pub fn init(
        self: *PrimaryExpression,
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

    pub fn get_range(self: *const PrimaryExpression) struct { usize, usize } {
        return switch (self.*) {
            .int, .float, .string, .identifier => |t| .{ t.start_pos, t.end_pos() },
            .paren => |p_struct| .{ p_struct.lparen.start_pos, p_struct.rparen.end_pos() },
        };
    }

    pub fn deinit(
        self: *PrimaryExpression,
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
                try std.testing.expectEqualDeep("322", inner_exp.exp.*.primary.int.value);
                try std.testing.expectEqualDeep(TokenType.Int, inner_exp.exp.*.primary.int.token_type);
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
