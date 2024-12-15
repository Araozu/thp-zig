const std = @import("std");
const lexic = @import("lexic");
const expression = @import("expression.zig");
const types = @import("./types.zig");
const utils = @import("./utils.zig");
const variable = @import("./variable.zig");

const TokenStream = types.TokenStream;
const ParseError = types.ParseError;

pub const Statement = union(enum) {
    VariableBinding: *variable.VariableBinding,

    /// Parses a Statement and return the position of the next token
    pub fn init(target: *Statement, tokens: *const TokenStream, pos: usize, allocator: std.mem.Allocator) ParseError!usize {
        // try to parse a variable definition

        var vardef: variable.VariableBinding = undefined;
        var parse_failed = false;
        const vardef_end = vardef.init(tokens, pos, allocator) catch |err| switch (err) {
            error.Unmatched => blk: {
                parse_failed = true;
                break :blk 0;
            },
            else => {
                return err;
            },
        };
        if (!parse_failed) {
            // return the parsed variable definition
            target.* = .{
                .VariableBinding = &vardef,
            };
            return vardef_end;
        }

        // fail
        return ParseError.Unmatched;
    }

    pub fn deinit(self: @This()) void {
        switch (self) {
            .VariableBinding => |v| v.deinit(),
        }
    }
};

test "should parse a variable declaration statement" {
    const input = "var my_variable = 322";
    const tokens = try lexic.tokenize(input, std.testing.allocator);
    defer tokens.deinit();

    var statement: Statement = undefined;
    _ = try statement.init(&tokens, 0, std.testing.allocator);
    defer statement.deinit();

    switch (statement) {
        .VariableBinding => |v| {
            try std.testing.expectEqual(true, v.is_mutable);
        },
    }
}

test "should fail on other constructs" {
    const input = "a_function_call(322)";
    const tokens = try lexic.tokenize(input, std.testing.allocator);
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
