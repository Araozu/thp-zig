const std = @import("std");
const lexic = @import("lexic");
const semantic = @import("semantic");
const error_context = @import("context");

const m_pratt_expression = @import("./expression/pratt_expression.zig");
const types = @import("./types.zig");
const utils = @import("./utils.zig");
const context = @import("./context.zig");
const m_id = @import("./ids.zig");

const PrattExpression = m_pratt_expression.PrattExpression;

const TokenStream = types.TokenStream;
const ParseError = types.ParseError;
const Visitor = semantic.Visitor;
const VisitorError = semantic.VisitorError;

pub const VariableBinding = struct {
    is_mutable: bool,
    datatype: ?*lexic.Token,
    identifier: *lexic.Token,
    expression: PrattExpression,
    id: u64,

    /// Parses a variable binding and returns the position of the next token
    /// of the form:
    ///
    /// ```thp
    ///     val|var identifier = expression
    /// ```
    pub fn init(
        target: *VariableBinding,
        pos: usize,
        ctx: *const context.ParserContext,
    ) ParseError!?usize {
        std.debug.assert(pos < ctx.tokens.items.len);

        var current_pos = pos;

        // try to parse a var keyword
        var variable_keyword: *lexic.Token = undefined;
        var variable_is_mutable = false;

        // Try to find `var`
        if (utils.expect_token_type(lexic.TokenType.K_Var, &ctx.tokens.items[current_pos])) |token| {
            variable_keyword = token;
            variable_is_mutable = true;
        } else if (utils.expect_token_type(lexic.TokenType.K_Val, &ctx.tokens.items[current_pos])) |token| {
            variable_keyword = token;
            variable_is_mutable = false;
        } else {
            // nothing found, return unmatched
            return null;
        }

        // check there is still input
        current_pos += 1;
        if (ctx.oob(current_pos)) {
            var err = try ctx.err.create_and_append_error(
                "Incomplete variable declaration",
                variable_keyword.start_pos,
                variable_keyword.start_pos + variable_keyword.value.len,
            );
            // FIXME: should also refer to a `val` keyword,
            // by dynamically creating the error message
            try err.add_label(ctx.err.create_error_label(
                "Expected an identifier or datatype after this `var`",
                variable_keyword.start_pos,
                variable_keyword.start_pos + variable_keyword.value.len,
            ));

            return ParseError.Error;
        }

        // ==============================
        //   Datatype
        // ==============================

        const r_token = &ctx.tokens.items[current_pos];
        var datatype_token: ?*lexic.Token = null;

        if (utils.expect_token_type(.Datatype, r_token) != null) {
            datatype_token = r_token;
            current_pos += 1;

            // Assert that theres a next token
            if (ctx.oob(current_pos)) {
                var err = try ctx.err.create_and_append_error("Incomplete variable declaration", r_token.start_pos, r_token.end_pos());
                try err.add_label(ctx.err.create_error_label("Expected a identifier after this datatype", r_token.start_pos, r_token.end_pos()));
                return ParseError.Error;
            }
        }

        // ==============================
        //   Identifier
        // ==============================

        // try to parse an identifier
        const id_token = &ctx.tokens.items[current_pos];
        const identifier = if (utils.expect_token_type(.Identifier, id_token)) |i| i else {
            const faulty_token = &ctx.tokens.items[current_pos];
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
        current_pos += 1;
        if (ctx.oob(current_pos)) {
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
        const equal_sign = if (utils.expect_operator("=", &ctx.tokens.items[current_pos])) |x| x else {
            const faulty_token = &ctx.tokens.items[current_pos];
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

        // ==============================
        //   Expression
        // ==============================

        // parse expression
        current_pos += 1;
        if (ctx.oob(current_pos)) {
            var err = try ctx.err.create_and_append_error("", equal_sign.start_pos, equal_sign.start_pos + equal_sign.value.len);
            try err.add_label(ctx.err.create_error_label(
                "Expected an expression after this equal sign",
                equal_sign.start_pos,
                equal_sign.start_pos + equal_sign.value.len,
            ));
            return ParseError.Error;
        }

        var exp: PrattExpression = undefined;
        const next_pos = try exp.init(current_pos, ctx) orelse {
            const faulty_token = &ctx.tokens.items[current_pos];
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
            .is_mutable = variable_is_mutable,
            .datatype = datatype_token,
            .identifier = identifier,
            .expression = exp,
            .id = m_id.generate_id(),
        };
        return next_pos;
    }

    pub fn accept(self: *const VariableBinding, comptime ReturnType: type, v: *const Visitor(ReturnType)) VisitorError!ReturnType {
        return try v.visitVariableBinding(self);
    }

    pub fn deinit(
        self: *@This(),
        ctx: *const context.ParserContext,
    ) void {
        self.expression.deinit(ctx);
    }
};

test "should parse a minimal var" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var my_variable = 322";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    const next_pos = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    try std.testing.expectEqual(next_pos, 4);
    try std.testing.expect(binding.is_mutable);
    try std.testing.expect(binding.datatype == null);
    try std.testing.expect(binding.datatype == null);
    try std.testing.expectEqualStrings("my_variable", binding.identifier.value);
    const expr = binding.expression;
    switch (expr) {
        .primary => |primary_exp| switch (primary_exp.*) {
            .int => |n| {
                try std.testing.expectEqualStrings("322", n.value);
            },
            else => {
                try std.testing.expect(false);
            },
        },
        else => try std.testing.expect(false),
    }
}

test "should return null if stream doesnt start with var" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "different_token_stream()";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

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
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

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
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

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
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

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
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

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
    const input = "var my_id = %@!";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

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

// ==============================================================================
// EXTENSIVE TESTS FOR VARIABLE BINDING PARSER
// ==============================================================================

// ------------------------------------------------------------------------------
// val keyword tests (immutable variables)
// ------------------------------------------------------------------------------

test "val: should parse a minimal val binding" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "val x = 1";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    const next_pos = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    try std.testing.expectEqual(4, next_pos);
    try std.testing.expect(!binding.is_mutable); // val is immutable
    try std.testing.expect(binding.datatype == null);
    try std.testing.expectEqualStrings("x", binding.identifier.value);
}

test "val: should verify identifier token positions" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "val my_var = 42";
    //             0123456789...
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    // identifier "my_var" starts at position 4
    try std.testing.expectEqual(4, binding.identifier.start_pos);
    try std.testing.expectEqual(10, binding.identifier.end_pos());
    try std.testing.expectEqualStrings("my_var", binding.identifier.value);
}

test "val: incomplete declaration after val keyword" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "val ";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        try std.testing.expectEqual(1, err_ctx.errors.items.len);
        const error_data = err_ctx.errors.items[0];
        try std.testing.expectEqualStrings("Incomplete variable declaration", error_data.reason);
        // error should point to "val" at position 0-3
        try std.testing.expectEqual(0, error_data.start_position);
        try std.testing.expectEqual(3, error_data.end_position);
        return;
    };
    defer binding.deinit(&parser_context);
    try std.testing.expect(false);
}

// ------------------------------------------------------------------------------
// var keyword tests (mutable variables)
// ------------------------------------------------------------------------------

test "var: should parse with longer identifier" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var a_very_long_variable_name = 999";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    const next_pos = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    try std.testing.expectEqual(4, next_pos);
    try std.testing.expect(binding.is_mutable);
    try std.testing.expectEqualStrings("a_very_long_variable_name", binding.identifier.value);
}

test "var: verify token positions with extra spaces" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var   spaced   =   100";
    //             0123456789012345678901
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    // "spaced" should start at position 6 (after "var   ")
    try std.testing.expectEqual(6, binding.identifier.start_pos);
    try std.testing.expectEqual(12, binding.identifier.end_pos());
}

// ------------------------------------------------------------------------------
// Datatype annotation tests
// ------------------------------------------------------------------------------

test "datatype: should parse var with datatype annotation" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var Int count = 0";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    const next_pos = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    try std.testing.expectEqual(5, next_pos); // var, Int, count, =, 0
    try std.testing.expect(binding.is_mutable);
    try std.testing.expect(binding.datatype != null);
    try std.testing.expectEqualStrings("Int", binding.datatype.?.value);
    try std.testing.expectEqualStrings("count", binding.identifier.value);
}

test "datatype: should parse val with datatype annotation" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "val String name = 42";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    const next_pos = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    try std.testing.expectEqual(5, next_pos);
    try std.testing.expect(!binding.is_mutable);
    try std.testing.expect(binding.datatype != null);
    try std.testing.expectEqualStrings("String", binding.datatype.?.value);
    try std.testing.expectEqualStrings("name", binding.identifier.value);
}

test "datatype: verify datatype token position" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var Bool flag = 1";
    //             01234567890123456
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    // "Bool" starts at position 4
    try std.testing.expect(binding.datatype != null);
    try std.testing.expectEqual(4, binding.datatype.?.start_pos);
    try std.testing.expectEqual(8, binding.datatype.?.end_pos());

    // "flag" starts at position 9
    try std.testing.expectEqual(9, binding.identifier.start_pos);
    try std.testing.expectEqual(13, binding.identifier.end_pos());
}

test "datatype: error when identifier missing after datatype" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var Int ";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        try std.testing.expectEqual(1, err_ctx.errors.items.len);
        const error_data = err_ctx.errors.items[0];
        try std.testing.expectEqualStrings("Incomplete variable declaration", error_data.reason);
        // error should point to the datatype "Int" at position 4-7
        try std.testing.expectEqual(4, error_data.start_position);
        try std.testing.expectEqual(7, error_data.end_position);
        return;
    };
    defer binding.deinit(&parser_context);
    try std.testing.expect(false);
}

test "datatype: error when non-identifier after datatype" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var Int 123";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        try std.testing.expectEqual(1, err_ctx.errors.items.len);
        const error_data = err_ctx.errors.items[0];
        try std.testing.expectEqualStrings("Invalid variable declaration", error_data.reason);
        // error should point to "123" at position 8
        try std.testing.expectEqual(8, error_data.start_position);
        try std.testing.expectEqual(11, error_data.end_position);
        return;
    };
    defer binding.deinit(&parser_context);
    try std.testing.expect(false);
}

// ------------------------------------------------------------------------------
// Equal sign error tests
// ------------------------------------------------------------------------------

test "equal sign: error when missing equal sign after identifier" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var x ";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        try std.testing.expectEqual(1, err_ctx.errors.items.len);
        const error_data = err_ctx.errors.items[0];
        try std.testing.expectEqualStrings("Incomplete variable declaration", error_data.reason);
        // error should point to identifier "x" at position 4-5
        try std.testing.expectEqual(4, error_data.start_position);
        try std.testing.expectEqual(5, error_data.end_position);
        try std.testing.expectEqual(1, error_data.labels.items.len);
        const label = error_data.labels.items[0];
        try std.testing.expectEqual(4, label.start);
        try std.testing.expectEqual(5, label.end);
        return;
    };
    defer binding.deinit(&parser_context);
    try std.testing.expect(false);
}

test "equal sign: error when wrong token instead of equal sign" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var x + 5";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        try std.testing.expectEqual(1, err_ctx.errors.items.len);
        const error_data = err_ctx.errors.items[0];
        try std.testing.expectEqualStrings("Invalid variable declaration", error_data.reason);
        // error should point to "+" at position 6
        try std.testing.expectEqual(6, error_data.start_position);
        try std.testing.expectEqual(7, error_data.end_position);
        return;
    };
    defer binding.deinit(&parser_context);
    try std.testing.expect(false);
}

test "equal sign: error when colon instead of equal sign" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "val name : 10";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        const error_data = err_ctx.errors.items[0];
        try std.testing.expectEqualStrings("Invalid variable declaration", error_data.reason);
        return;
    };
    defer binding.deinit(&parser_context);
    try std.testing.expect(false);
}

// ------------------------------------------------------------------------------
// Expression error tests
// ------------------------------------------------------------------------------

test "expression: error when expression missing after equal sign" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var x = ";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        try std.testing.expectEqual(1, err_ctx.errors.items.len);
        const error_data = err_ctx.errors.items[0];
        // error points to the equal sign
        try std.testing.expectEqual(6, error_data.start_position);
        try std.testing.expectEqual(7, error_data.end_position);
        try std.testing.expectEqual(1, error_data.labels.items.len);
        const label = error_data.labels.items[0];
        switch (label.message) {
            .static => |msg| try std.testing.expectEqualStrings("Expected an expression after this equal sign", msg),
            .dynamic => try std.testing.expect(false),
        }
        return;
    };
    defer binding.deinit(&parser_context);
    try std.testing.expect(false);
}

test "expression: error when invalid token instead of expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var x = )";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        const error_data = err_ctx.errors.items[0];
        try std.testing.expectEqualStrings("Invalid variable declaration", error_data.reason);
        // error should point to ")" at position 8
        try std.testing.expectEqual(8, error_data.start_position);
        try std.testing.expectEqual(9, error_data.end_position);
        return;
    };
    defer binding.deinit(&parser_context);
    try std.testing.expect(false);
}

// ------------------------------------------------------------------------------
// Non-matching input tests (should return null)
// ------------------------------------------------------------------------------

test "non-matching: should return null for identifier starting token" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "some_function()";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    const result = try binding.init(0, &parser_context);
    try std.testing.expect(result == null);
}

test "non-matching: should return null for number starting token" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "123 + 456";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    const result = try binding.init(0, &parser_context);
    try std.testing.expect(result == null);
}

test "non-matching: should return null for operator starting token" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "+ something";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    const result = try binding.init(0, &parser_context);
    try std.testing.expect(result == null);
}

test "non-matching: should return null for parenthesis starting token" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "(x + y)";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    const result = try binding.init(0, &parser_context);
    try std.testing.expect(result == null);
}

// ------------------------------------------------------------------------------
// Parsing from non-zero position tests
// ------------------------------------------------------------------------------

test "position: should parse from non-zero position" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    // Two statements: first is a number, second is a var declaration
    const input = "123\nvar x = 5";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    // Start parsing from position 2 (after "123" and newline)
    const next_pos = try binding.init(2, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    try std.testing.expectEqual(6, next_pos); // 123, \n, var, x, =, 5
    try std.testing.expect(binding.is_mutable);
    try std.testing.expectEqualStrings("x", binding.identifier.value);
}

// ------------------------------------------------------------------------------
// Error label message validation tests
// ------------------------------------------------------------------------------

test "error labels: verify label message for incomplete after var" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var ";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch {
        const error_data = err_ctx.errors.items[0];
        try std.testing.expectEqual(1, error_data.labels.items.len);
        const label = error_data.labels.items[0];
        switch (label.message) {
            .static => |msg| try std.testing.expectEqualStrings("Expected an identifier or datatype after this `var`", msg),
            .dynamic => try std.testing.expect(false),
        }
        return;
    };
    try std.testing.expect(false);
}

test "error labels: verify label message for invalid identifier" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var 999";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch {
        const error_data = err_ctx.errors.items[0];
        try std.testing.expectEqual(1, error_data.labels.items.len);
        const label = error_data.labels.items[0];
        switch (label.message) {
            .static => try std.testing.expect(false),
            .dynamic => |msg| try std.testing.expectEqualStrings("Expected an identifier here, found a Int", msg),
        }
        return;
    };
    try std.testing.expect(false);
}

test "error labels: verify label message for missing equal sign" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var x 5";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch {
        const error_data = err_ctx.errors.items[0];
        try std.testing.expectEqual(1, error_data.labels.items.len);
        const label = error_data.labels.items[0];
        switch (label.message) {
            .static => try std.testing.expect(false),
            .dynamic => |msg| try std.testing.expectEqualStrings("Expected an equal sign `=` here, found a Int", msg),
        }
        return;
    };
    try std.testing.expect(false);
}

// ------------------------------------------------------------------------------
// Expression value tests (simple expressions only)
// ------------------------------------------------------------------------------

test "expression: should parse with integer literal" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var num = 12345";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    switch (binding.expression) {
        .primary => |primary_exp| switch (primary_exp.*) {
            .int => |n| try std.testing.expectEqualStrings("12345", n.value),
            else => try std.testing.expect(false),
        },
        else => try std.testing.expect(false),
    }
}

test "expression: should parse with identifier expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var x = other_var";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    switch (binding.expression) {
        .primary => |primary_exp| switch (primary_exp.*) {
            .identifier => |id| try std.testing.expectEqualStrings("other_var", id.value),
            else => try std.testing.expect(false),
        },
        else => try std.testing.expect(false),
    }
}

// ------------------------------------------------------------------------------
// Complex position/offset tests
// ------------------------------------------------------------------------------

test "positions: all token positions in complete declaration" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "val Int counter = 100";
    //             012345678901234567890
    //             0         1         2
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    // Verify datatype "Int" position
    try std.testing.expect(binding.datatype != null);
    try std.testing.expectEqual(4, binding.datatype.?.start_pos);
    try std.testing.expectEqual(7, binding.datatype.?.end_pos());
    try std.testing.expectEqualStrings("Int", binding.datatype.?.value);

    // Verify identifier "counter" position
    try std.testing.expectEqual(8, binding.identifier.start_pos);
    try std.testing.expectEqual(15, binding.identifier.end_pos());
    try std.testing.expectEqualStrings("counter", binding.identifier.value);
}

test "positions: single char identifier and expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var a = 0";
    //             012345678
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    // identifier "a" at position 4
    try std.testing.expectEqual(4, binding.identifier.start_pos);
    try std.testing.expectEqual(5, binding.identifier.end_pos());
}

// ------------------------------------------------------------------------------
// Edge cases
// ------------------------------------------------------------------------------

test "edge case: identifier same as reserved word suffix" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var variable = 1";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    try std.testing.expectEqualStrings("variable", binding.identifier.value);
}

test "edge case: identifier starting with underscore" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var _private = 1";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    try std.testing.expectEqualStrings("_private", binding.identifier.value);
}

test "edge case: multiple underscores in identifier" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "val __double__underscore__ = 42";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    try std.testing.expectEqualStrings("__double__underscore__", binding.identifier.value);
}

test "edge case: zero as expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var zero = 0";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    switch (binding.expression) {
        .primary => |primary_exp| switch (primary_exp.*) {
            .int => |n| try std.testing.expectEqualStrings("0", n.value),
            else => try std.testing.expect(false),
        },
        else => try std.testing.expect(false),
    }
}

// ------------------------------------------------------------------------------
// Error position precision tests
// ------------------------------------------------------------------------------

test "error positions: precise position for number instead of identifier" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var 42 = 1";
    //             0123456789
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch {
        const error_data = err_ctx.errors.items[0];
        // "42" is at position 4-6
        try std.testing.expectEqual(4, error_data.start_position);
        try std.testing.expectEqual(6, error_data.end_position);
        return;
    };
    try std.testing.expect(false);
}

test "error positions: precise position for operator instead of identifier" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "val + = 1";
    //             012345678
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch {
        const error_data = err_ctx.errors.items[0];
        // "+" is at position 4-5
        try std.testing.expectEqual(4, error_data.start_position);
        try std.testing.expectEqual(5, error_data.end_position);
        return;
    };
    try std.testing.expect(false);
}

test "error positions: precise position for paren instead of equal" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var x ( 1";
    //             012345678
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch {
        const error_data = err_ctx.errors.items[0];
        // "(" is at position 6-7
        try std.testing.expectEqual(6, error_data.start_position);
        try std.testing.expectEqual(7, error_data.end_position);
        return;
    };
    try std.testing.expect(false);
}

// ------------------------------------------------------------------------------
// Datatype with different capitalization patterns
// ------------------------------------------------------------------------------

test "datatype: custom datatype name" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var MyCustomType value = 1";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    try std.testing.expect(binding.datatype != null);
    try std.testing.expectEqualStrings("MyCustomType", binding.datatype.?.value);
    try std.testing.expectEqualStrings("value", binding.identifier.value);
}

// ------------------------------------------------------------------------------
// Combined error scenario tests
// ------------------------------------------------------------------------------

test "combined: var with datatype but missing identifier at end" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "val String";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        const error_data = err_ctx.errors.items[0];
        try std.testing.expectEqualStrings("Incomplete variable declaration", error_data.reason);
        // should point to "String" datatype
        try std.testing.expectEqual(4, error_data.start_position);
        try std.testing.expectEqual(10, error_data.end_position);
        return;
    };
    try std.testing.expect(false);
}

test "combined: var with identifier but no equal sign and no expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var abc";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        const error_data = err_ctx.errors.items[0];
        try std.testing.expectEqualStrings("Incomplete variable declaration", error_data.reason);
        // should point to identifier "abc"
        try std.testing.expectEqual(4, error_data.start_position);
        try std.testing.expectEqual(7, error_data.end_position);
        return;
    };
    try std.testing.expect(false);
}

test "combined: var with datatype, identifier, but missing equal and expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "val Int num";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        const error_data = err_ctx.errors.items[0];
        try std.testing.expectEqualStrings("Incomplete variable declaration", error_data.reason);
        // should point to identifier "num"
        try std.testing.expectEqual(8, error_data.start_position);
        try std.testing.expectEqual(11, error_data.end_position);
        return;
    };
    try std.testing.expect(false);
}

test "combined: var with datatype, identifier, equal but no expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "val Int num = ";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    _ = binding.init(0, &parser_context) catch |err| {
        try std.testing.expectEqual(ParseError.Error, err);
        const error_data = err_ctx.errors.items[0];
        // should point to "=" at position 12-13
        try std.testing.expectEqual(12, error_data.start_position);
        try std.testing.expectEqual(13, error_data.end_position);
        return;
    };
    try std.testing.expect(false);
}

// ------------------------------------------------------------------------------
// Token count / next position tests
// ------------------------------------------------------------------------------

test "next position: minimal declaration returns correct position" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var x = 1";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    const next_pos = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    // var(0), x(1), =(2), 1(3) => next is 4
    try std.testing.expectEqual(4, next_pos);
}

test "next position: with datatype returns correct position" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var Int x = 1";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    const next_pos = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    // var(0), Int(1), x(2), =(3), 1(4) => next is 5
    try std.testing.expectEqual(5, next_pos);
}

test "next position: verify tokens remain after parsing" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var x = 1 + 2";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var binding: VariableBinding = undefined;
    const next_pos = try binding.init(0, &parser_context) orelse @panic("Fail");
    defer binding.deinit(&parser_context);

    // The expression parser consumes "1 + 2" as a binary expression
    // var(0), x(1), =(2), 1(3), +(4), 2(5) => next is 6
    try std.testing.expectEqual(6, next_pos);
}
