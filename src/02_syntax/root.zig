const std = @import("std");
const lexic = @import("lexic");
const Token = lexic.Token;
const TokenType = lexic.TokenType;

const TokenStream = std.ArrayList(Token);

const ParseError = error{
    Unmatched,
    Error,
};

const Statement = union(enum) {
    VariableBinding: u8,
};

const VariableBinding = struct {
    is_mutable: bool,
    datatype: ?*Token,
    identifier: *Token,
    expression: Expression,

    fn parse() !@This() {}
};

const Expression = union(enum) {
    number: *const Token,

    /// Attempts to parse an expression from a token stream.
    fn parse(tokens: *const TokenStream, pos: usize) ParseError!@This() {
        std.debug.assert(pos < tokens.items.len);

        const t = tokens.items[pos];
        if (t.token_type != TokenType.Int) {
            return ParseError.Unmatched;
        }

        return .{
            .number = &t,
        };
    }
};

test {
    std.testing.refAllDecls(@This());
}

test "should parse expression" {
    const input = "322";
    const tokens = try lexic.tokenize(input, std.testing.allocator);
    defer tokens.deinit();

    const expr = try Expression.parse(&tokens, 0);
    try std.testing.expectEqualDeep("322", expr.number.value);
    try std.testing.expectEqualDeep(TokenType.Int, expr.number.token_type);
}
