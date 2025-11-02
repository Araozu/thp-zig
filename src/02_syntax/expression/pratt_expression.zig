const std = @import("std");
const lexic = @import("lexic");
const context = @import("../context.zig");
const types = @import("../types.zig");

const m_primary_expression = @import("primary_expression.zig");
const PrimaryExpression = m_primary_expression.PrimaryExpression;
const Token = lexic.Token;
const ParseError = types.ParseError;

const Precedence = enum(u8) {
    PREC_NONE = 0,
    PREC_ASSIGNMENT = 1, // =
    PREC_OR = 2, // or
    PREC_AND = 3, // and
    PREC_EQUALITY = 4, // == !=
    PREC_COMPARISON = 5, // < > <= >=
    PREC_TERM = 6, // + -
    PREC_FACTOR = 7, // * /
    PREC_UNARY = 8, // -
    PREC_CALL = 9, // . ()
    PREC_PRIMARY = 10,

    pub fn compare(self: Precedence, other: Precedence) std.math.Order {
        return std.math.order(@intFromEnum(self), @intFromEnum(other));
    }
};

pub const PrattExpression = union(enum) {
    primary: *PrimaryExpression,
    binary: struct {
        left: *PrattExpression,
        operator: *const lexic.Token,
        right: *PrattExpression,
    },

    const Self = @This();

    pub fn init(
        self: *Self,
        pos: usize,
        ctx: *const context.ParserContext,
    ) !?usize {
        return parse_with_precedence(self, pos, ctx, Precedence.PREC_ASSIGNMENT);
    }

    fn parse_with_precedence(
        self: *Self,
        pos: usize,
        ctx: *const context.ParserContext,
        min_precedence: Precedence,
    ) !?usize {
        if (ctx.oob(pos)) return null;
        var next_pos = pos;

        var temp_expr = try ctx.allocator.create(Self);

        // Parse a prefix (primary expression or unary)
        next_pos = parse_prefix(temp_expr, next_pos, ctx) catch |e| {
            ctx.allocator.destroy(temp_expr);
            return e;
        } orelse {
            ctx.allocator.destroy(temp_expr);
            return null;
        };

        // Parse binary expressions
        while (!ctx.oob(next_pos)) {
            const token = &ctx.tokens.items[next_pos];
            const op_prec = get_infix_precedence(token);

            // Stop if the operator has lower precedence than minimum
            if (op_prec.compare(min_precedence) != .gt) {
                break;
            }

            const operator_token = token;
            next_pos += 1; // consume operator

            // Parse the right side with higher precedence
            var right_expr = try ctx.allocator.create(Self);
            errdefer ctx.allocator.destroy(right_expr);

            next_pos = try parse_with_precedence(right_expr, next_pos, ctx, op_prec) orelse {
                _ = try ctx.err.create_and_append_error(
                    "Expected expression after operator",
                    operator_token.start_pos,
                    operator_token.end_pos(),
                );
                // Clean up left_expr before returning error
                temp_expr.deinit(ctx);
                ctx.allocator.destroy(temp_expr);
                return ParseError.Error;
            };
            errdefer right_expr.deinit(ctx);

            // Create new binary expression and make it the new left for next iteration
            const new_binary = try ctx.allocator.create(Self);
            errdefer ctx.allocator.destroy(new_binary);

            new_binary.* = .{ .binary = .{
                .left = temp_expr,
                .operator = operator_token,
                .right = right_expr,
            } };

            temp_expr = new_binary;
        }

        self.* = temp_expr.*;
        ctx.allocator.destroy(temp_expr);
        return next_pos;
    }

    fn parse_prefix(
        self: *Self,
        pos: usize,
        ctx: *const context.ParserContext,
    ) !?usize {
        if (ctx.oob(pos)) return null;
        var next_pos = pos;

        // TODO: parse unary operator (grammar only allows for `-` and `!`)

        // Try parsing primary expression
        var parsed_primary = try ctx.allocator.create(PrimaryExpression);
        errdefer ctx.allocator.destroy(parsed_primary);

        next_pos = try parsed_primary.init(next_pos, ctx) orelse {
            ctx.allocator.destroy(parsed_primary);
            return null;
        };
        self.* = .{
            .primary = parsed_primary,
        };
        return next_pos;
    }

    /// Get the precedence of an infix operator at the current token
    fn get_infix_precedence(token: *const Token) Precedence {
        if (token.token_type != .Operator) {
            return .PREC_NONE;
        }

        const op = token.value;

        // Arithmetic operators
        if (std.mem.eql(u8, op, "+") or std.mem.eql(u8, op, "-")) {
            return .PREC_TERM;
        }

        return .PREC_NONE;
    }

    pub fn deinit(
        self: *Self,
        ctx: *const context.ParserContext,
    ) void {
        switch (self.*) {
            .primary => |p| {
                p.deinit(ctx);
                ctx.allocator.destroy(p);
            },
            .binary => |b| {
                b.left.deinit(ctx);
                ctx.allocator.destroy(b.left);
                b.right.deinit(ctx);
                ctx.allocator.destroy(b.right);
            },
        }
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const error_context = @import("context");

const TokenType = lexic.TokenType;

test "should parse a primary expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "322";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);
    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };

    var expr: PrattExpression = undefined;
    const next_pos = try expr.init(0, &parser_context) orelse {
        try expect(false);
        return;
    };
    defer expr.deinit(&parser_context);
    try expectEqual(1, next_pos);
}

test "should parse a binary expression with +" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "1 + 2";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);
    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };

    var expr: PrattExpression = undefined;
    const next_pos = try expr.init(0, &parser_context) orelse {
        try expect(false);
        return;
    };
    defer expr.deinit(&parser_context);

    // Should consume all 3 tokens: "1", "+", "2"
    try expectEqual(3, next_pos);

    // Should be a binary expression
    try expect(expr == .binary);
    try expect(std.mem.eql(u8, expr.binary.operator.value, "+"));
}

test "should fail on incomplete binary expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "1 +";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);
    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };

    var expr: PrattExpression = undefined;
    const result = expr.init(0, &parser_context);

    // Should return an error
    try std.testing.expectError(ParseError.Error, result);

    // Should have created an error message
    try expect(err_ctx.errors.items.len > 0);
}
