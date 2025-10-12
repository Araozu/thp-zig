const std = @import("std");
const lexic = @import("lexic");
const context = @import("./context.zig");
const error_context = @import("context");
const types = @import("./types.zig");

const Token = lexic.Token;
const TokenType = lexic.TokenType;
const ParseError = types.ParseError;

/// Parses a whole expression, which includes:
/// - simple numbers/strings
/// - identifiers
/// - function calls
/// - array access
pub const Expression = union(enum) {
    int: *const Token,
    float: *const Token,
    string: *const Token,
    identifier: *const Token,
    paren: *Expression,

    /// Attempts to parse an expression from a token stream.
    ///
    /// Receives a pointer to the memory for initialization,
    /// returns the position of the next token
    pub fn init(
        self: *Expression,
        pos: usize,
        ctx: *const context.ParserContext,
    ) !?usize {
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
            // FIXME:
            // Parse expression inside paren

            // check theres tokens left after the paren
            if (ctx.oob(pos + 1)) {
                var err = try ctx.err.create_and_append_error("Syntax error", t.start_pos, t.end_pos());
                try err.add_label(ctx.err.create_error_label(
                    "There is nothing after this open paren",
                    t.start_pos,
                    t.end_pos(),
                ));

                return ParseError.Error;
            }

            var inner_exp = try ctx.allocator.create(Expression);
            errdefer ctx.allocator.destroy(inner_exp);

            const next_pos_maybe = try inner_exp.init(pos + 1, ctx);
            const next_pos = next_pos_maybe orelse {
                //
                var err = try ctx.err.create_and_append_error("Syntax error", t.start_pos, t.end_pos());
                try err.add_label(ctx.err.create_error_label(
                    "There is nothing after this open paren",
                    t.start_pos,
                    t.end_pos(),
                ));

                return ParseError.Error;
            };

            _ = next_pos;
        }

        return null;
    }

    pub fn deinit(
        self: *Expression,
        ctx: *const context.ParserContext,
    ) void {
        switch (self) {
            .paren => |inner_exp| {
                inner_exp.deinit(ctx);
                ctx.allocator.destroy(inner_exp);
            },
            else => {},
        }
    }
};

test "should parse expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "322";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var expr: Expression = undefined;
    if (try expr.init(0, &parser_context)) |_| {
        try std.testing.expectEqualDeep("322", expr.int.value);
        try std.testing.expectEqualDeep(TokenType.Int, expr.int.token_type);
        return;
    }
    try std.testing.expect(false);
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
    var expr: Expression = undefined;
    if (try expr.init(0, &parser_context)) |_| {
        std.debug.print("v: {s}", .{expr.int.value});
        try std.testing.expect(false);
    }

    return;
}
