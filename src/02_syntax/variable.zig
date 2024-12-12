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
    expression: *expression.Expression,
    alloc: std.mem.Allocator,

    /// Parses a variable binding
    fn init(target: *VariableBinding, tokens: *const TokenStream, pos: usize, allocator: std.mem.Allocator) ParseError!void {
        std.debug.assert(pos < tokens.items.len);

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

        // parse equal sign
        if (pos + 2 >= tokens.items.len) return ParseError.Error;
        const equal_sign = utils.expect_operator("=", &tokens.items[pos + 2]) catch {
            return ParseError.Error;
        };
        _ = equal_sign;

        // parse expression
        if (pos + 3 >= tokens.items.len) return ParseError.Error;
        var exp = allocator.create(expression.Expression) catch {
            return ParseError.Error;
        };
        errdefer allocator.destroy(exp);
        try exp.init(tokens, pos + 3);

        // return
        target.* = .{
            .is_mutable = true,
            .datatype = null,
            .identifier = identifier,
            .expression = exp,
            .alloc = allocator,
        };
    }

    fn deinit(self: *VariableBinding) void {
        self.alloc.destroy(self.expression);
    }
};

test "should parse a minimal var" {
    const input = "var my_variable = 322";
    const tokens = try lexic.tokenize(input, std.testing.allocator);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    try binding.init(&tokens, 0, std.testing.allocator);
    defer binding.deinit();

    try std.testing.expectEqual(true, binding.is_mutable);
}

test "should fail is it doesnt start with var" {
    const input = "different_token_stream()";
    const tokens = try lexic.tokenize(input, std.testing.allocator);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    binding.init(&tokens, 0, std.testing.allocator) catch |err| {
        try std.testing.expectEqual(ParseError.Unmatched, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail if the idenfier is missing" {
    const input = "var ";
    const tokens = try lexic.tokenize(input, std.testing.allocator);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    binding.init(&tokens, 0, std.testing.allocator) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        return;
    };

    try std.testing.expect(false);
}
