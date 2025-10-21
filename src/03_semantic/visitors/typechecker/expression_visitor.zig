const std = @import("std");

const syntax = @import("syntax");
const type_visitor = @import("./typechecker_visitor.zig");
const visitor = @import("../../visitor.zig");
const types = @import("../../types.zig");

const CallExpression = syntax.CallExpression;
const TypecheckerVisitor = type_visitor.TypecheckerVisitor;
const VisitorError = visitor.VisitorError;
const Type = types.Type;

pub fn visit(self: *TypecheckerVisitor, node: *const CallExpression) VisitorError!Type {
    _ = self;
    switch (node.*) {
        .function => {
            std.debug.print("TODO: get expression of function call\n", .{});
            return Type.Untyped;
        },
        .primary => |expr| switch (expr) {
            .float => return Type.Float,
            .int => return Type.Int,
            .string => return Type.String,
            .identifier => |token| {
                if (std.mem.eql(u8, token.*.value, "true")) {
                    return Type.Bool;
                } else if (std.mem.eql(u8, token.*.value, "false")) {
                    return Type.Bool;
                }

                // FIXME: actually get type
                std.debug.print("Not implemented: get type of an identifier.\n", .{});
            },
            .paren => |_| {
                return Type.Untyped;
                // FIXME: restore typing of paren-wrapped thing
                // return try visit(self, inner_exp.exp);
            },
        },
    }

    // FIXME:
    // Process other expression types

    return Type.Untyped;
}
