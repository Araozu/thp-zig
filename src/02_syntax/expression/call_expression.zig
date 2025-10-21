//! Parses a "CallExpression" tree, which is either a
//! function call, an array call (TBD)
//! or a plain value.
//!
//! ```ebnf
//! CallExpression = Primary "(" Arguments_list? ")"
//!                | Primary "[" Array_expression "]"
//!                | Primary
//! ```
const std = @import("std");
const lexic = @import("lexic");
const context = @import("../context.zig");
const types = @import("../types.zig");
const error_context = @import("context");

const Token = lexic.Token;
const TokenType = lexic.TokenType;
const ParseError = types.ParseError;
const PrimaryExpression = @import("../expression.zig").Expression;

pub const CallExpression = union(enum) {
    function: struct {
        primary: PrimaryExpression,
    },
    primary: PrimaryExpression,

    pub fn init(self: *CallExpression, pos: usize, ctx: *const context.ParserContext) !?usize {
        std.debug.assert(pos < ctx.tokens.items.len);
        var current_pos = pos;

        // parse the primary
        var primary_expr: PrimaryExpression = undefined;
        current_pos = try primary_expr.init(current_pos, ctx) orelse return null;
        errdefer primary_expr.deinit(ctx);

        // check if function call
        if (ctx.oob(current_pos)) {
            // no more output, return just a Primary
            self.* = .{ .primary = primary_expr };
            return current_pos;
        }
        const l_paren_t = &ctx.tokens.items[current_pos];

        if (l_paren_t.token_type == TokenType.LeftParen) {
            const pos_after_fun = try parse_arguments_list(current_pos, ctx);
            self.* = .{ .function = .{ .primary = primary_expr } };
            return pos_after_fun;
        }
        // TODO: check if array expression

        // neither function or array matched, return the primary
        self.* = .{ .primary = primary_expr };
        return current_pos;
    }

    fn parse_arguments_list(pos: usize, ctx: *const context.ParserContext) !usize {
        var current_pos = pos;

        const lparen_t = &ctx.tokens.items[current_pos];

        // TODO: actually parse argumenst

        // assert r paren
        current_pos += 1;
        if (ctx.oob(current_pos)) {
            // throw error, unmatched paren
            var err = try ctx.err.create_and_append_error("Unmatched paren", lparen_t.start_pos, lparen_t.end_pos());
            try err.add_label(ctx.err.create_error_label("This paren is not closed", lparen_t.start_pos, lparen_t.end_pos()));

            return ParseError.Error;
        }
        const r_paren_t = &ctx.tokens.items[current_pos];
        if (r_paren_t.token_type == TokenType.RightParen) {
            // TODO: should return the parsed arguments
            return current_pos;
        } else {
            // throw error, unmatched paren
            const err = try ctx.err.create_and_append_error("Syntax error", r_paren_t.start_pos, r_paren_t.end_pos());
            const token_name = r_paren_t.token_type.to_string();
            const error_name = try std.fmt.allocPrint(ctx.err.allocator, "Expected a right paren here, found a {s}", .{token_name});
            try err.add_label(ctx.err.create_error_label_alloc(
                error_name,
                r_paren_t.start_pos,
                r_paren_t.end_pos(),
            ));

            return ParseError.Error;
        }
    }

    pub fn deinit(self: *CallExpression, ctx: *const context.ParserContext) void {
        _ = self;
        _ = ctx;
    }
};

// ```ebnf
// CallExpression = Primary "(" Arguments_list? ")"
//                | Primary "[" Array_expression "]"
//                | Primary
// ```

test "should parse a primary expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "322";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: CallExpression = undefined;
    defer expr.deinit(&parser_context);

    if (try expr.init(0, &parser_context)) |_| {
        try std.testing.expectEqualDeep("322", expr.primary.int.value);
        try std.testing.expectEqualDeep(TokenType.Int, expr.primary.int.token_type);
        return;
    } else try std.testing.expect(false);
}

test "should parse a function call expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "print()";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var expr: CallExpression = undefined;
    if (try expr.init(0, &parser_context)) |_| {
        defer expr.deinit(&parser_context);

        try std.testing.expectEqualDeep(expr.function.primary.identifier.value, "print");
        return;
    } else try std.testing.expect(false);
}

// This should test that an arbitrary expression is used as a function, like:
// `(1 + 2)()`, the typechecker with later on decide what to do with it
//
// test "should parse a expresion used as function call" {
//     var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
//     defer err_ctx.deinit();
//     const input = "print()";
//     var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
//     defer tokens.deinit(std.testing.allocator);
//
//     const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
//     var expr: CallExpression = undefined;
//     if (try expr.init(0, &parser_context)) |_| {
//         defer expr.deinit(&parser_context);
//
//         try std.testing.expectEqualDeep(expr.function.primary.identifier.value, "print");
//         return;
//     } else try std.testing.expect(false);
// }
