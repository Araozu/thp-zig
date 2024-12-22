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
    /// Receives a pointer to the memory for initialization
    pub fn init(self: *@This(), tokens: *const std.ArrayList(Token), pos: usize) error{Unmatched}!void {
        std.debug.assert(pos < tokens.items.len);

        const t = tokens.items[pos];
        if (t.token_type != TokenType.Int) {
            return error.Unmatched;
        }

        self.* = .{
            .number = &t,
        };
    }
};

test "should parse expression" {
    const input = "322";
    var error_list = std.ArrayList(*errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
    defer tokens.deinit();

    var expr: Expression = undefined;
    try expr.init(&tokens, 0);
    try std.testing.expectEqualDeep("322", expr.number.value);
    try std.testing.expectEqualDeep(TokenType.Int, expr.number.token_type);
}

test "should fail on non expression" {
    const input = "identifier";
    var error_list = std.ArrayList(*errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
    defer tokens.deinit();

    var expr: Expression = undefined;
    expr.init(&tokens, 0) catch |err| {
        try std.testing.expectEqual(ParseError.Unmatched, err);
        return;
    };

    std.debug.print("v: {s}", .{expr.number.value});
    try std.testing.expect(false);
}
