const std = @import("std");
const lexic = @import("lexic");
const expression = @import("expression.zig");
const types = @import("./types.zig");
const utils = @import("./utils.zig");
const variable = @import("./variable.zig");
const errors = @import("errors");
const context = @import("context");

const TokenStream = types.TokenStream;
const ParseError = types.ParseError;

pub const Statement = struct {
    value: union(enum) {
        variableBinding: *variable.VariableBinding,
    },

    /// Parses a Statement and return the position of the next token
    pub fn init(
        target: *Statement,
        tokens: *const TokenStream,
        pos: usize,
        ctx: *context.CompilerContext,
    ) ParseError!?usize {
        // try to parse a variable definition

        var vardef = try ctx.allocator.create(variable.VariableBinding);
        errdefer ctx.allocator.destroy(vardef);

        const vardef_result = try vardef.init(tokens, pos, ctx);
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

    pub fn deinit(
        self: @This(),
        ctx: *context.CompilerContext,
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
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "var my_variable = 322";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, &ctx);
    defer tokens.deinit();

    var statement: Statement = undefined;
    _ = try statement.init(&tokens, 0, undefined, std.testing.allocator);
    defer statement.deinit();

    switch (statement.value) {
        .variableBinding => |v| {
            try std.testing.expectEqual(true, v.is_mutable);
            try std.testing.expectEqualDeep("my_variable", v.identifier.value);
        },
    }
}

test "should fail on other constructs" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "a_function_call(322)";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, &ctx);
    defer tokens.deinit();

    var statement: Statement = undefined;
    const result = try statement.init(&tokens, 0, undefined, std.testing.allocator);
    if (result == null) {
        // good path
        return;
    }

    try std.testing.expect(false);
}
