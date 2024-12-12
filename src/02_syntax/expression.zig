const std = @import("std");
const lexic = @import("lexic");
const Token = lexic.Token;
const TokenType = lexic.TokenType;
const ParseError = @import("./types.zig").ParseError;

pub const Expression = union(enum) {
    number: *const Token,

    /// Attempts to parse an expression from a token stream.
    ///
    /// Receives a pointer to the memory for initialization
    pub fn init(target: *Expression, tokens: *const std.ArrayList(Token), pos: usize) error{Unmatched}!void {
        std.debug.assert(pos < tokens.items.len);

        const t = tokens.items[pos];
        if (t.token_type != TokenType.Int) {
            return error.Unmatched;
        }

        target.* = .{
            .number = &t,
        };
    }
};

test "should parse expression" {
    const input = "322";
    const tokens = try lexic.tokenize(input, std.testing.allocator);
    defer tokens.deinit();

    var expr: Expression = undefined;
    try expr.init(&tokens, 0);
    try std.testing.expectEqualDeep("322", expr.number.value);
    try std.testing.expectEqualDeep(TokenType.Int, expr.number.token_type);
}

test "should fail on non expression" {
    const input = "identifier";
    const tokens = try lexic.tokenize(input, std.testing.allocator);
    defer tokens.deinit();

    var expr: Expression = undefined;
    expr.init(&tokens, 0) catch |err| {
        try std.testing.expectEqual(ParseError.Unmatched, err);
        return;
    };

    std.debug.print("v: {s}", .{expr.number.value});
    try std.testing.expect(false);
}
