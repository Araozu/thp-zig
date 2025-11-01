const std = @import("std");
const lexic = @import("lexic");
const types = @import("./types.zig");
const utils = @import("./utils.zig");
const variable = @import("./variable.zig");
const context = @import("./context.zig");
const error_context = @import("context");
const semantic = @import("semantic");
const m_call_expression = @import("./expression/call_expression.zig");

const TokenStream = types.TokenStream;
const ParseError = types.ParseError;
const Visitor = semantic.Visitor;
const VisitorError = semantic.VisitorError;
const CallExpression = m_call_expression.CallExpression;

pub const Statement = union(enum) {
    variableBinding: *variable.VariableBinding,
    expression: CallExpression,

    /// Parses a Statement and returns the position of the next token
    pub fn init(
        target: *Statement,
        pos: usize,
        ctx: *const context.ParserContext,
    ) ParseError!?usize {
        // try to parse a variable definition
        {
            var vardef = try ctx.allocator.create(variable.VariableBinding);
            errdefer ctx.allocator.destroy(vardef);

            const vardef_result = try vardef.init(pos, ctx);
            if (vardef_result) |next_pos| {
                // variable definition parsed
                // return the parsed variable definition
                target.* = .{ .variableBinding = vardef };
                return next_pos;
            }

            // manually deallocate
            ctx.allocator.destroy(vardef);
        }

        // Try to parse a expression
        exp: {
            var call_expression: CallExpression = undefined;
            const next_pos = try call_expression.init(pos, ctx) orelse break :exp;
            target.* = .{ .expression = call_expression };
            return next_pos;
        }

        return null;
    }

    /// Method for accepting a visitor
    pub fn accept(self: *const Statement, v: *const Visitor) VisitorError!void {
        try v.visitStatement(self);
    }

    pub fn deinit(
        self: *Statement,
        ctx: *const context.ParserContext,
    ) void {
        switch (self.*) {
            .variableBinding => |v| {
                v.deinit(ctx);
                ctx.allocator.destroy(v);
            },
            .expression => |*e| {
                e.deinit(ctx);
            },
        }
    }
};

test "should parse a variable declaration statement" {
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
    var statement: Statement = undefined;

    if (try statement.init(0, &parser_context)) |next_pos| {
        defer statement.deinit(&parser_context);

        switch (statement) {
            .variableBinding => |v| {
                try std.testing.expectEqual(true, v.is_mutable);
                try std.testing.expectEqualDeep("my_variable", v.identifier.value);
                try std.testing.expectEqual(4, next_pos);
            },
            else => @panic("Expected variable binding"),
        }
    } else {
        try std.testing.expect(false);
    }
}

test "should parse a expression as a statement" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "print(322)";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };
    var statement: Statement = undefined;
    const next_pos = try statement.init(0, &parser_context) orelse @panic("Expected a statement");
    defer statement.deinit(&parser_context);

    try std.testing.expectEqual(next_pos, 5);
    try std.testing.expectEqualDeep("print", statement.expression.primary.identifier.value);
}
