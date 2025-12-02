const std = @import("std");

const syntax = @import("syntax");
const type_visitor = @import("./typechecker_visitor.zig");
const visitor = @import("../../visitor.zig");
const types = @import("../../types.zig");

const PrattExpression = syntax.PrattExpression;
const PrimaryExpression = syntax.Expression;
const TypecheckerVisitor = type_visitor.TypecheckerVisitor;
const VisitorError = visitor.VisitorError;
const Type = types.Type;

pub fn visit(self: *TypecheckerVisitor, node: *const PrattExpression) VisitorError!Type {
    switch (node.*) {
        .binary => return typecheck_binary_expression(self, node),
        .function => |*funcall| {
            // Check that the function_id resolves to a function type
            const t_function_id = try visit(self, funcall.callee);

            // Assert its a function type
            switch (t_function_id) {
                .Function => |t_function| {
                    // TODO: assert args are correct when the function calls other things

                    // get type of the function

                    // check arity

                    // get types of params
                    for (funcall.arguments.items) |arg| {
                        const v = self.visitor();
                        _ = try arg.accept(Type, &v);
                    }

                    // check types of params

                    return t_function.return_t.*;
                },
                else => {
                    // FIXME: compute function_id token range
                    var new_error = try self.err.create_and_append_error("Type mismatch in function call", 0, 1);
                    // FIXME: show the declaration of the identifier, AND its usage
                    {
                        const function_id_tname = t_function_id.to_str();
                        const err_msg = try std.fmt.allocPrint(self.err.allocator, "This expression has type `{s}`, but it is called as a function", .{function_id_tname});
                        const err_msg_label = self.err.create_error_label_alloc(err_msg, 0, 1);
                        try new_error.add_label(err_msg_label);
                    }

                    return VisitorError.SemanticError;
                },
            }

            std.debug.print("TODO: get expression of function call\n", .{});
            return Type.Untyped;
        },
        .primary => |expr| return try typecheck_primary_expression(self, expr),
    }

    // FIXME:
    // Process other expression types

    return Type.Untyped;
}

pub fn typecheck_binary_expression(self: *TypecheckerVisitor, node: *const PrattExpression) VisitorError!Type {
    const binary_expr = &node.binary;
    const expr_visitor = self.visitor();

    const left_type = try binary_expr.left.accept(Type, &expr_visitor);
    const right_type = try binary_expr.right.accept(Type, &expr_visitor);

    // const left_start, const left_end = binary_expr.left.get_range();
    // const right_start, const right_end = binary_expr.right.get_range();

    // Typecheck with defined operator types
    const t_operator = self.scope.get(binary_expr.operator.value) orelse {
        // FIXME: error handling
        std.debug.panic("Operator not found in symbol table during typechecking...", .{});
    };
    const t_op = switch (t_operator.t) {
        .Function => |*t_op| t_op,
        else => {
            // FIXME: error handling
            std.debug.panic("Operator is not a function type during typechecking...", .{});
        },
    };

    if (t_op.params.len != 2) {
        // FIXME: error handling
        std.debug.panic("Operator is not binded to a 2ary fun", .{});
    }

    if (!t_op.params[0].eql(&left_type)) {
        // FIXME: error handling
        std.debug.panic("Operator left type no match", .{});
    }
    if (!t_op.params[1].eql(&right_type)) {
        // FIXME: error handling
        std.debug.panic("Operator right type no match", .{});
    }
    return t_op.return_t.*;
}

pub fn typecheck_primary_expression(self: *TypecheckerVisitor, node: *const PrimaryExpression) VisitorError!Type {
    switch (node.*) {
        .float => return Type.Float,
        .int => return Type.Int,
        .string => return Type.String,
        .identifier => |token| {
            // NOTE: should the lexer emit those as their own tokens?
            if (std.mem.eql(u8, token.*.value, "true")) {
                return Type.Bool;
            } else if (std.mem.eql(u8, token.*.value, "false")) {
                return Type.Bool;
            }

            // get the type from the symbol table
            const t_id = self.scope.get(token.value) orelse {
                var new_error = try self.err.create_and_append_error(
                    "Undeclared identifier",
                    token.start_pos,
                    token.end_pos(),
                );
                {
                    const err_msg = try std.fmt.allocPrint(self.err.allocator, "Identifier `{s}` doesn't exist in this scope", .{token.value});
                    const err_msg_label = self.err.create_error_label_alloc(
                        err_msg,
                        token.start_pos,
                        token.end_pos(),
                    );
                    try new_error.add_label(err_msg_label);
                }
                return VisitorError.SemanticError;
            };

            // TODO: throw if untyped?!
            return t_id.t;
        },
        .paren => |inner_exp| {
            return try visit(self, inner_exp.exp);
        },
    }
}
