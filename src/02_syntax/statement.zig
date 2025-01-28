const std = @import("std");
const lexic = @import("lexic");
const expression = @import("expression.zig");
const types = @import("./types.zig");
const utils = @import("./utils.zig");
const variable = @import("./variable.zig");
const errors = @import("errors");

const TokenStream = types.TokenStream;
const ParseError = types.ParseError;

pub const Statement = struct {
    alloc: std.mem.Allocator,
    value: union(enum) {
        variableBinding: *variable.VariableBinding,
    },

    /// Parses a Statement and return the position of the next token
    pub fn init(
        target: *Statement,
        tokens: *const TokenStream,
        pos: usize,
        allocator: std.mem.Allocator,
    ) ParseError!usize {
        // try to parse a variable definition

        var vardef = allocator.create(variable.VariableBinding) catch {
            return ParseError.OutOfMemory;
        };
        errdefer allocator.destroy(vardef);

        if (try vardef.init(tokens, pos, allocator)) |vardef_end| {
            // variable definition parsed
            // return the parsed variable definition
            target.* = .{
                .alloc = allocator,
                .value = .{ .variableBinding = vardef },
            };
            return vardef_end;
        }
        // TODO: handle other errors of vardef parsing

        // fail
        return ParseError.Unmatched;
    }

    pub fn deinit(self: @This()) void {
        switch (self.value) {
            .variableBinding => |v| {
                v.deinit();
                self.alloc.destroy(v);
            },
        }
    }
};

test "should parse a variable declaration statement" {
    const input = "var my_variable = 322";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
    defer tokens.deinit();

    var statement: Statement = undefined;
    _ = try statement.init(&tokens, 0, std.testing.allocator);
    defer statement.deinit();

    switch (statement.value) {
        .variableBinding => |v| {
            try std.testing.expectEqual(true, v.is_mutable);
            try std.testing.expectEqualDeep("my_variable", v.identifier.value);
        },
    }
}

test "should fail on other constructs" {
    const input = "a_function_call(322)";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
    defer tokens.deinit();

    var statement: Statement = undefined;
    _ = statement.init(&tokens, 0, std.testing.allocator) catch |e| switch (e) {
        error.Unmatched => {
            return;
        },
        else => {
            try std.testing.expect(false);
            return;
        },
    };

    try std.testing.expect(false);
}
