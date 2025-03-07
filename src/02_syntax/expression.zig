const std = @import("std");
const lexic = @import("lexic");
const context = @import("context");

const Token = lexic.Token;
const TokenType = lexic.TokenType;

pub const Expression = union(enum) {
    number: *const Token,

    /// Attempts to parse an expression from a token stream.
    ///
    /// Receives a pointer to the memory for initialization,
    /// returns the position of the next token
    pub fn init(self: *@This(), tokens: *const std.ArrayList(Token), pos: usize) ?usize {
        std.debug.assert(pos < tokens.items.len);

        const t = tokens.items[pos];
        if (t.token_type != TokenType.Int) {
            return null;
        }

        self.* = .{
            .number = &t,
        };
        return pos + 1;
    }
};

test "should parse expression" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "322";
    const tokens = try lexic.tokenize(input, std.testing.allocator, &ctx);
    defer tokens.deinit();

    var expr: Expression = undefined;
    if (expr.init(&tokens, 0)) |_| {
        try std.testing.expectEqualDeep("322", expr.number.value);
        try std.testing.expectEqualDeep(TokenType.Int, expr.number.token_type);
        return;
    }
    try std.testing.expect(false);
}

test "should fail on non expression" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "identifier";
    const tokens = try lexic.tokenize(input, std.testing.allocator, &ctx);
    defer tokens.deinit();

    var expr: Expression = undefined;
    if (expr.init(&tokens, 0)) |_| {
        std.debug.print("v: {s}", .{expr.number.value});
        try std.testing.expect(false);
    }

    return;
}
