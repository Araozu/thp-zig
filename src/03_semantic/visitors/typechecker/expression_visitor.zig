const std = @import("std");

const syntax = @import("syntax");
const type_visitor = @import("./typechecker_visitor.zig");
const visitor = @import("../../visitor.zig");
const types = @import("../../types.zig");

const Expression = syntax.Expression;
const TypecheckerVisitor = type_visitor.TypecheckerVisitor;
const VisitorError = visitor.VisitorError;
const Type = types.Type;

pub fn visit(self: *TypecheckerVisitor, node: *const Expression) VisitorError!Type {
    switch (node.*) {
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
        .paren => |inner_exp| {
            return try visit(self, inner_exp.exp);
        },
    }

    // FIXME:
    // Process other expression types

    return Type.Untyped;
}
