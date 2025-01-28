const std = @import("std");
const lexic = @import("lexic");
const errors = @import("errors");
const Token = lexic.Token;
const TokenType = lexic.TokenType;
const ParseError = @import("./types.zig").ParseError;

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
    const input = "322";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
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
    const input = "identifier";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
    defer tokens.deinit();

    var expr: Expression = undefined;
    if (expr.init(&tokens, 0)) |_| {
        std.debug.print("v: {s}", .{expr.number.value});
        try std.testing.expect(false);
    }

    return;
}
