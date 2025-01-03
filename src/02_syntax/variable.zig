const std = @import("std");
const lexic = @import("lexic");
const expression = @import("expression.zig");
const types = @import("./types.zig");
const utils = @import("./utils.zig");
const errors = @import("errors");

const TokenStream = types.TokenStream;
const ParseError = types.ParseError;

pub const VariableBinding = struct {
    is_mutable: bool,
    datatype: ?*lexic.Token,
    identifier: *lexic.Token,
    expression: *expression.Expression,
    alloc: std.mem.Allocator,

    /// Parses a variable binding and returns the position of the next token
    pub fn init(target: *VariableBinding, tokens: *const TokenStream, pos: usize, allocator: std.mem.Allocator) ParseError!usize {
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

        const exp = allocator.create(expression.Expression) catch {
            return ParseError.OutOfMemory;
        };
        errdefer allocator.destroy(exp);
        exp.init(tokens, pos + 3) catch {
            return ParseError.Error;
        };

        // return
        target.* = .{
            .is_mutable = true,
            .datatype = null,
            .identifier = identifier,
            .expression = exp,
            .alloc = allocator,
        };
        // TODO: when expression parses more than one token this will break.
        return pos + 4;
    }

    pub fn deinit(self: @This()) void {
        self.alloc.destroy(self.expression);
    }
};

test "should parse a minimal var" {
    const input = "var my_variable = 322";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    _ = try binding.init(&tokens, 0, std.testing.allocator);
    defer binding.deinit();

    try std.testing.expectEqual(true, binding.is_mutable);
    try std.testing.expect(binding.datatype == null);
    try std.testing.expectEqualDeep("my_variable", binding.identifier.value);
    const expr = binding.expression;
    switch (expr.*) {
        .number => |n| {
            try std.testing.expectEqualDeep("322", n.value);
        },
    }
}

test "should fail is it doesnt start with var" {
    const input = "different_token_stream()";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    _ = binding.init(&tokens, 0, std.testing.allocator) catch |err| {
        try std.testing.expectEqual(ParseError.Unmatched, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail if the identifier is missing" {
    const input = "var ";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    _ = binding.init(&tokens, 0, std.testing.allocator) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail if there is not an identifier after var" {
    const input = "var 322";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    _ = binding.init(&tokens, 0, std.testing.allocator) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail if the equal sign is missing" {
    const input = "var my_id    ";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    _ = binding.init(&tokens, 0, std.testing.allocator) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail if the equal sign is not found" {
    const input = "var my_id is string";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    _ = binding.init(&tokens, 0, std.testing.allocator) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        return;
    };

    try std.testing.expect(false);
}

test "should fail if the expression parsing fails" {
    const input = "var my_id = ehhh";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    _ = binding.init(&tokens, 0, std.testing.allocator) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        return;
    };

    try std.testing.expect(false);
}
