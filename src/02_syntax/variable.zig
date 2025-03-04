const std = @import("std");
const lexic = @import("lexic");
const expression = @import("expression.zig");
const types = @import("./types.zig");
const utils = @import("./utils.zig");
const context = @import("context");

const TokenStream = types.TokenStream;
const ParseError = types.ParseError;

pub const VariableBinding = struct {
    is_mutable: bool,
    datatype: ?*lexic.Token,
    identifier: *lexic.Token,
    expression: *expression.Expression,

    /// Parses a variable binding and returns the position of the next token
    pub fn init(
        target: *VariableBinding,
        tokens: *const TokenStream,
        pos: usize,
        ctx: *context.CompilerContext,
    ) ParseError!?usize {
        std.debug.assert(pos < tokens.items.len);

        // try to parse a var keyword
        const var_keyword = if (utils.expect_token_type(lexic.TokenType.K_Var, &tokens.items[pos])) |t| t else {
            return null;
        };

        // check there is still input
        if (pos + 1 >= tokens.items.len) {
            var err = try ctx.create_and_append_error(
                "Incomplete variable declaration",
                var_keyword.start_pos,
                var_keyword.start_pos + var_keyword.value.len,
            );
            try err.add_label(ctx.create_error_label(
                "Expected an identifier after this `var`",
                var_keyword.start_pos,
                var_keyword.start_pos + var_keyword.value.len,
            ));

            return ParseError.Error;
        }

        // try to parse an identifier
        const identifier = if (utils.expect_token_type(lexic.TokenType.Identifier, &tokens.items[pos + 1])) |i| i else {
            const faulty_token = &tokens.items[pos + 1];
            var err = try ctx.create_and_append_error(
                "Invalid variable declaration",
                faulty_token.start_pos,
                faulty_token.start_pos + faulty_token.value.len,
            );
            const token_name = faulty_token.token_type.to_string();
            const error_name = try std.fmt.allocPrint(ctx.allocator, "Expected an identifier here, found a {s}", .{token_name});
            try err.add_label(ctx.create_error_label_alloc(
                error_name,
                faulty_token.start_pos,
                faulty_token.start_pos + faulty_token.value.len,
            ));

            return ParseError.Error;
        };

        // parse equal sign
        if (pos + 2 >= tokens.items.len) {
            var err = try ctx.create_and_append_error(
                "Incomplete variable declaration",
                identifier.start_pos,
                identifier.start_pos + identifier.value.len,
            );
            try err.add_label(ctx.create_error_label(
                "Expected a equal sign `=` after this identifier",
                identifier.start_pos,
                identifier.start_pos + identifier.value.len,
            ));

            return ParseError.Error;
        }
        const equal_sign = if (utils.expect_operator("=", &tokens.items[pos + 2])) |x| x else {
            const faulty_token = &tokens.items[pos + 2];
            var err = try ctx.create_and_append_error(
                "Invalid variable declaration",
                faulty_token.start_pos,
                faulty_token.start_pos + faulty_token.value.len,
            );
            const token_name = faulty_token.token_type.to_string();
            const error_name = try std.fmt.allocPrint(ctx.allocator, "Expected an equal sign `=` here, found a {s}", .{token_name});
            try err.add_label(ctx.create_error_label_alloc(
                error_name,
                faulty_token.start_pos,
                faulty_token.start_pos + faulty_token.value.len,
            ));
            return ParseError.Error;
        };

        // parse expression
        if (pos + 3 >= tokens.items.len) {
            var err = try ctx.create_and_append_error("", equal_sign.start_pos, equal_sign.start_pos + equal_sign.value.len);
            try err.add_label(ctx.create_error_label(
                "Expected an expression after this equal sign",
                equal_sign.start_pos,
                equal_sign.start_pos + equal_sign.value.len,
            ));
            return ParseError.Error;
        }

        const exp = try ctx.allocator.create(expression.Expression);
        errdefer ctx.allocator.destroy(exp);
        const next_pos = if (exp.init(tokens, pos + 3)) |x| x else {
            const faulty_token = &tokens.items[pos + 3];
            var err = try ctx.create_and_append_error(
                "Invalid variable declaration",
                faulty_token.start_pos,
                faulty_token.start_pos + faulty_token.value.len,
            );
            const token_name = faulty_token.token_type.to_string();
            const error_name = try std.fmt.allocPrint(ctx.allocator, "Expected an expression here, found a {s}", .{token_name});
            try err.add_label(ctx.create_error_label_alloc(
                error_name,
                faulty_token.start_pos,
                faulty_token.start_pos + faulty_token.value.len,
            ));
            return ParseError.Error;
        };

        // assign and return
        target.* = .{
            .is_mutable = true,
            .datatype = null,
            .identifier = identifier,
            .expression = exp,
        };
        return next_pos;
    }

    pub fn deinit(
        self: @This(),
        ctx: *context.CompilerContext,
    ) void {
        ctx.allocator.destroy(self.expression);
    }
};

test "should parse a minimal var" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "var my_variable = 322";
    const tokens = try lexic.tokenize(input, &ctx);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    _ = try binding.init(&tokens, 0, &ctx);
    defer binding.deinit(&ctx);

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

test "should return null if stream doesnt start with var" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "different_token_stream()";
    const tokens = try lexic.tokenize(input, &ctx);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    if (try binding.init(&tokens, 0, &ctx)) |_| {
        try std.testing.expect(false);
    }
}

test "should fail if the identifier is missing" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "var ";
    const tokens = try lexic.tokenize(input, &ctx);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    _ = binding.init(&tokens, 0, &ctx) catch |err| {
        try std.testing.expectEqual(1, ctx.errors.items.len);
        const error_data = ctx.errors.items[0];

        try std.testing.expectEqual(ParseError.Error, err);
        try std.testing.expectEqualStrings("Incomplete variable declaration", error_data.reason);
        try std.testing.expectEqual(0, error_data.start_position);
        try std.testing.expectEqual(3, error_data.end_position);
        try std.testing.expectEqual(1, error_data.labels.items.len);
        const l = error_data.labels.items[0];
        try std.testing.expectEqual(0, l.start);
        try std.testing.expectEqual(3, l.end);
        return;
    };
    defer binding.deinit(&ctx);

    try std.testing.expect(false);
}

test "should fail if there is not an identifier after var" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "var 322";
    const tokens = try lexic.tokenize(input, &ctx);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    _ = binding.init(&tokens, 0, &ctx) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        return;
    };
    defer binding.deinit(&ctx);

    try std.testing.expect(false);
}

test "should fail if the equal sign is missing" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "var my_id    ";
    const tokens = try lexic.tokenize(input, &ctx);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    _ = binding.init(&tokens, 0, &ctx) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        return;
    };
    defer binding.deinit(&ctx);

    try std.testing.expect(false);
}

test "should fail if the equal sign is not found" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "var my_id is string";
    const tokens = try lexic.tokenize(input, &ctx);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    _ = binding.init(&tokens, 0, &ctx) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        return;
    };
    defer binding.deinit(&ctx);

    try std.testing.expect(false);
}

test "should fail if the expression parsing fails" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "var my_id = ehhh";
    const tokens = try lexic.tokenize(input, &ctx);
    defer tokens.deinit();

    var binding: VariableBinding = undefined;
    _ = binding.init(&tokens, 0, &ctx) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        return;
    };
    defer binding.deinit(&ctx);

    try std.testing.expect(false);
}
