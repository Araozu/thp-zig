const std = @import("std");
const lexic = @import("lexic");
const context = @import("./context.zig");
const error_context = @import("context");

const Token = lexic.Token;
const TokenType = lexic.TokenType;

pub const Expression = union(enum) {
    number: *const Token,

    /// Attempts to parse an expression from a token stream.
    ///
    /// Receives a pointer to the memory for initialization,
    /// returns the position of the next token
    pub fn init(
        self: *Expression,
        pos: usize,
        ctx: *const context.ParserContext,
    ) ?usize {
        std.debug.assert(pos < ctx.tokens.items.len);

        const t = &ctx.tokens.items[pos];
        if (t.token_type != TokenType.Int) {
            return null;
        }

        self.* = .{
            .number = t,
        };
        return pos + 1;
    }
};

test "should parse expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "322";
    const tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit();

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var expr: Expression = undefined;
    if (expr.init(0, &parser_context)) |_| {
        try std.testing.expectEqualDeep("322", expr.number.value);
        try std.testing.expectEqualDeep(TokenType.Int, expr.number.token_type);
        return;
    }
    try std.testing.expect(false);
}

test "should fail on non expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "identifier";
    const tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit();

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var expr: Expression = undefined;
    if (expr.init(0, &parser_context)) |_| {
        std.debug.print("v: {s}", .{expr.number.value});
        try std.testing.expect(false);
    }

    return;
}
