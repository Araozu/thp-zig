const std = @import("std");
const lexic = @import("lexic");
const expression = @import("expression.zig");
const types = @import("./types.zig");
const utils = @import("./utils.zig");
const variable = @import("./variable.zig");
const context = @import("./context.zig");
const error_context = @import("context");
const semantic = @import("semantic");

const TokenStream = types.TokenStream;
const ParseError = types.ParseError;
const Visitor = semantic.Visitor;

pub const Statement = struct {
    value: union(enum) {
        variableBinding: *variable.VariableBinding,
    },

    /// Parses a Statement and returns the position of the next token
    pub fn init(
        target: *Statement,
        pos: usize,
        ctx: *const context.ParserContext,
    ) ParseError!?usize {
        // try to parse a variable definition

        var vardef = try ctx.allocator.create(variable.VariableBinding);
        errdefer ctx.allocator.destroy(vardef);

        const vardef_result = try vardef.init(pos, ctx);
        if (vardef_result) |vardef_end| {
            // variable definition parsed
            // return the parsed variable definition
            target.* = .{
                .value = .{ .variableBinding = vardef },
            };
            return vardef_end;
        }

        // manually deallocate
        ctx.allocator.destroy(vardef);
        return null;
    }

    /// Method for accepting a visitor
    pub fn accept(self: *const Statement, v: *Visitor) void {
        v.visitStatement(self);
    }

    pub fn deinit(
        self: @This(),
        ctx: *const context.ParserContext,
    ) void {
        switch (self.value) {
            .variableBinding => |v| {
                v.deinit(ctx);
                ctx.allocator.destroy(v);
            },
        }
    }
};

test "should parse a variable declaration statement" {
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
    var statement: Statement = undefined;
    _ = try statement.init(0, &parser_context);
    defer statement.deinit(&parser_context);

    switch (statement.value) {
        .variableBinding => |v| {
            try std.testing.expectEqual(true, v.is_mutable);
            try std.testing.expectEqualDeep("my_variable", v.identifier.value);
        },
    }
}

test "should fail on other constructs" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "a_function_call(322)";
    const tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit();

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var statement: Statement = undefined;
    const result = try statement.init(0, &parser_context);
    if (result == null) {
        // good path
        return;
    }
    defer statement.deinit(&parser_context);

    try std.testing.expect(false);
}
