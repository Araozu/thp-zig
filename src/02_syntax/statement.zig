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

    fn init(target: *Statement, tokens: *const TokenStream, pos: usize, allocator: std.mem.Allocator) ParseError!void {
        // try to parse a variable definition

        var vardef: variable.VariableBinding = undefined;
        var parse_failed = false;
        vardef.init(tokens, pos, allocator) catch |err| switch (err) {
            error.Unmatched => {
                parse_failed = true;
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
            return;
        }

        // fail
        return ParseError.Unmatched;
    }

    fn deinit(self: @This()) void {
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
    try statement.init(&tokens, 0, std.testing.allocator);
    defer statement.deinit();

    // try std.testing.expectEqual(true, statement.is_mutable);
}
