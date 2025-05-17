const std = @import("std");
const lexic = @import("lexic");
const semantic = @import("semantic");
const expression = @import("expression.zig");
const types = @import("./types.zig");
const utils = @import("./utils.zig");
const context = @import("./context.zig");
const error_context = @import("context");

const TokenStream = types.TokenStream;
const ParseError = types.ParseError;
const Visitor = semantic.Visitor;
const VisitorError = semantic.VisitorError;

pub const VariableBinding = struct {
    is_mutable: bool,
    datatype: ?*lexic.Token,
    identifier: *lexic.Token,
    expression: *expression.Expression,

    /// Parses a variable binding and returns the position of the next token
    pub fn init(
        target: *VariableBinding,
        pos: usize,
        ctx: *const context.ParserContext,
    ) ParseError!?usize {
        std.debug.assert(pos < ctx.tokens.items.len);

        // try to parse a var keyword
        const var_keyword = if (utils.expect_token_type(lexic.TokenType.K_Var, &ctx.tokens.items[pos])) |t| t else {
            return null;
        };

        // check there is still input
        if (pos + 1 >= ctx.tokens.items.len) {
            var err = try ctx.err.create_and_append_error(
                "Incomplete variable declaration",
                var_keyword.start_pos,
                var_keyword.start_pos + var_keyword.value.len,
            );
            try err.add_label(ctx.err.create_error_label(
                "Expected an identifier after this `var`",
                var_keyword.start_pos,
                var_keyword.start_pos + var_keyword.value.len,
            ));

            return ParseError.Error;
        }

        // try to parse an identifier
        const identifier = if (utils.expect_token_type(lexic.TokenType.Identifier, &ctx.tokens.items[pos + 1])) |i| i else {
            const faulty_token = &ctx.tokens.items[pos + 1];
            var err = try ctx.err.create_and_append_error(
                "Invalid variable declaration",
                faulty_token.start_pos,
                faulty_token.start_pos + faulty_token.value.len,
            );
            const token_name = faulty_token.token_type.to_string();
            const error_name = try std.fmt.allocPrint(ctx.err.allocator, "Expected an identifier here, found a {s}", .{token_name});
            try err.add_label(ctx.err.create_error_label_alloc(
                error_name,
                faulty_token.start_pos,
                faulty_token.start_pos + faulty_token.value.len,
            ));

            return ParseError.Error;
        };

        // parse equal sign
        if (pos + 2 >= ctx.tokens.items.len) {
            var err = try ctx.err.create_and_append_error(
                "Incomplete variable declaration",
                identifier.start_pos,
                identifier.start_pos + identifier.value.len,
            );
            try err.add_label(ctx.err.create_error_label(
                "Expected a equal sign `=` after this identifier",
                identifier.start_pos,
                identifier.start_pos + identifier.value.len,
            ));

            return ParseError.Error;
        }
        const equal_sign = if (utils.expect_operator("=", &ctx.tokens.items[pos + 2])) |x| x else {
            const faulty_token = &ctx.tokens.items[pos + 2];
            var err = try ctx.err.create_and_append_error(
                "Invalid variable declaration",
                faulty_token.start_pos,
                faulty_token.start_pos + faulty_token.value.len,
            );
            const token_name = faulty_token.token_type.to_string();
            const error_name = try std.fmt.allocPrint(ctx.err.allocator, "Expected an equal sign `=` here, found a {s}", .{token_name});
            try err.add_label(ctx.err.create_error_label_alloc(
                error_name,
                faulty_token.start_pos,
                faulty_token.start_pos + faulty_token.value.len,
            ));
            return ParseError.Error;
        };

        // parse expression
        if (pos + 3 >= ctx.tokens.items.len) {
            var err = try ctx.err.create_and_append_error("", equal_sign.start_pos, equal_sign.start_pos + equal_sign.value.len);
            try err.add_label(ctx.err.create_error_label(
                "Expected an expression after this equal sign",
                equal_sign.start_pos,
                equal_sign.start_pos + equal_sign.value.len,
            ));
            return ParseError.Error;
        }

        const exp = try ctx.allocator.create(expression.Expression);
        errdefer ctx.allocator.destroy(exp);
        const next_pos = if (exp.init(pos + 3, ctx)) |x| x else {
            const faulty_token = &ctx.tokens.items[pos + 3];
            var err = try ctx.err.create_and_append_error(
                "Invalid variable declaration",
                faulty_token.start_pos,
                faulty_token.start_pos + faulty_token.value.len,
            );
            const token_name = faulty_token.token_type.to_string();
            const error_name = try std.fmt.allocPrint(ctx.err.allocator, "Expected an expression here, found a {s}", .{token_name});
            try err.add_label(ctx.err.create_error_label_alloc(
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

    pub fn accept(self: *const VariableBinding, v: *const Visitor) VisitorError!void {
        try v.visitVariableBinding(self);
    }

    pub fn deinit(
        self: @This(),
        ctx: *const context.ParserContext,
    ) void {
        ctx.allocator.destroy(self.expression);
    }
};

test "should parse a minimal var" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var my_variable = 322";
    const tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit();

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = try binding.init(0, &parser_context);
    defer binding.deinit(&parser_context);

    try std.testing.expectEqual(true, binding.is_mutable);
    try std.testing.expect(binding.datatype == null);
    try std.testing.expectEqualStrings("my_variable", binding.identifier.value);
    const expr = binding.expression;
    switch (expr.*) {
        .number => |n| {
            try std.testing.expectEqualStrings("322", n.value);
        },
    }
}

test "should return null if stream doesnt start with var" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "different_token_stream()";
    const tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit();

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    if (try binding.init(0, &parser_context)) |_| {
        try std.testing.expect(false);
    }
}

test "should fail if the identifier is missing" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var ";
    const tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit();

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(1, err_ctx.errors.items.len);
        const error_data = err_ctx.errors.items[0];

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
    defer binding.deinit(&parser_context);

    try std.testing.expect(false);
}

test "should fail if there is not an identifier after var" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var 322";
    const tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit();

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        return;
    };
    defer binding.deinit(&parser_context);

    try std.testing.expect(false);
}

test "should fail if the equal sign is missing" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var my_id    ";
    const tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit();

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        return;
    };
    defer binding.deinit(&parser_context);

    try std.testing.expect(false);
}

test "should fail if the equal sign is not found" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var my_id is string";
    const tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit();

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        return;
    };
    defer binding.deinit(&parser_context);

    try std.testing.expect(false);
}

test "should fail if the expression parsing fails" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var my_id = ehhh";
    const tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit();

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        return;
    };
    defer binding.deinit(&parser_context);

    try std.testing.expect(false);
}
