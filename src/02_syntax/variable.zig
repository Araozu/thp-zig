const std = @import("std");
const lexic = @import("lexic");
const expression = @import("expression.zig");
const types = @import("./types.zig");
const utils = @import("./utils.zig");

const TokenStream = types.TokenStream;
const ParseError = types.ParseError;

const VariableBinding = struct {
    is_mutable: bool,
    datatype: ?*lexic.Token,
    identifier: *lexic.Token,
    expression: expression.Expression,
    alloc: std.mem.Allocator,

    fn init(tokens: *const TokenStream, pos: usize, allocator: std.mem.Allocator) ParseError!@This() {
        std.debug.assert(pos < tokens.items.len);

        _ = allocator;

        // try to parse a var keyword
        const var_keyword = try utils.expect_token_type(lexic.TokenType.K_Var, &tokens.items[pos]);
        _ = var_keyword;

        // check there is still input
        if (pos + 1 >= tokens.items.len) {
            // return error
            return ParseError.Error;
        }

        // try to parse an identifier
        const identifier = utils.expect_token_type(lexic.TokenType.Identifier, &tokens.items[pos + 1]) catch {
            return ParseError.Error;
        };
        _ = identifier;

        // parse equal sign
        if (pos + 2 >= tokens.items.len) return ParseError.Error;
        const equal_sign = utils.expect_operator("=", &tokens.items[pos + 2]) catch {
            return ParseError.Error;
        };
        _ = equal_sign;

        // parse expression

        // provisional good return value
        return ParseError.Unmatched;
    }

    fn deinit(self: *@This()) void {
        _ = self;
    }
};

test "should parse a minimal var" {
    const input = "var my_variable =";
    const tokens = try lexic.tokenize(input, std.testing.allocator);
    defer tokens.deinit();

    const binding = VariableBinding.init(&tokens, 0, std.testing.allocator) catch |err| {
        try std.testing.expectEqual(ParseError.Unmatched, err);
        return;
    };

    try std.testing.expectEqual(false, binding.is_mutable);
}
