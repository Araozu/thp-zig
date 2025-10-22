const std = @import("std");

const syntax = @import("syntax");
const type_visitor = @import("./typechecker_visitor.zig");
const visitor = @import("../../visitor.zig");
const types = @import("../../types.zig");

const CallExpression = syntax.CallExpression;
const PrimaryExpression = syntax.Expression;
const TypecheckerVisitor = type_visitor.TypecheckerVisitor;
const VisitorError = visitor.VisitorError;
const Type = types.Type;

pub fn visit(self: *TypecheckerVisitor, node: *const CallExpression) VisitorError!Type {
    switch (node.*) {
        .function => |f| {
            // Check that the function_id resolves to a function type
            const t_function_id = try visit_primary_expression(self, &f.primary);

            // Assert its a function type
            switch (t_function_id) {
                .Function => {
                    // TODO: assert args are correct
                    // Compute & return return type
                },
                else => {
                    // throw error
                    // FIXME: compute function_id token range
                    const function_id_tname = t_function_id.to_str();
                    var new_error = try self.err.create_and_append_error("Type mismatch in function call", 0, 1);
                    {
                        const err_msg = try std.fmt.allocPrint(self.err.allocator, "This expression has type `{s}`, but it should be a Function", .{function_id_tname});
                        const err_msg_label = self.err.create_error_label_alloc(err_msg, 0, 1);
                        try new_error.add_label(err_msg_label);
                    }

                    return VisitorError.SemanticError;
                },
            }

            std.debug.print("TODO: get expression of function call\n", .{});
            return Type.Untyped;
        },
        .primary => |expr| return try visit_primary_expression(self, &expr),
    }

    // FIXME:
    // Process other expression types

    return Type.Untyped;
}

pub fn visit_primary_expression(self: *TypecheckerVisitor, node: *const PrimaryExpression) VisitorError!Type {
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
            return Type.Untyped;
        },
        .paren => |inner_exp| {
            return try visit(self, inner_exp.exp);
        },
    }
}
