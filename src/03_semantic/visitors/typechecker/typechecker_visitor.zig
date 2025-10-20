const std = @import("std");
const lexic = @import("lexic");
const syntax = @import("syntax");
const context = @import("context");

const types = @import("../../types.zig");
const symbol_table = @import("../../symbol_table.zig");
const visitor = @import("../../visitor.zig");

const TokenType = lexic.TokenType;
const ErrorCtx = context.ErrorContext;
const StringHashMap = std.StringHashMapUnmanaged;
const Scope = types.Scope;
const Type = types.Type;
const Visitor = visitor.Visitor;
const VisitorError = visitor.VisitorError;
const SymbolTable = symbol_table.SymbolTable;

const Statement = syntax.Statement;
const VariableBinding = syntax.VariableBinding;

const ExpressionVisitor = @import("./expression_visitor.zig");

pub const TypecheckerVisitor = struct {
    symbol_table: *const SymbolTable,
    scope: *Scope,
    alloc: std.mem.Allocator,
    err: *ErrorCtx,

    pub fn init(
        alloc: std.mem.Allocator,
        table: *const SymbolTable,
        s: *Scope,
        err: *ErrorCtx,
    ) TypecheckerVisitor {
        return TypecheckerVisitor{
            .scope = s,
            .symbol_table = table,
            .alloc = alloc,
            .err = err,
        };
    }

    pub fn visitStatement(ptr: *anyopaque, node: *const Statement) VisitorError!void {
        const self: *TypecheckerVisitor = @ptrCast(@alignCast(ptr));

        switch (node.value) {
            .variableBinding => |b| {
                try b.accept(&self.visitor());
            },
        }
    }

    pub fn visitVariableBinding(ptr: *anyopaque, node: *const VariableBinding) VisitorError!void {
        const self: *TypecheckerVisitor = @ptrCast(@alignCast(ptr));

        // ensure the binding is on the symbol table
        // get the type of the binding expression
        const expression_type = try ExpressionVisitor.visit(self, &node.expression);

        // get the type of the type hint, if any
        const hinted_type = if (node.datatype) |type_hint| switch (type_hint.token_type) {
            // Should match against Datatype and parse its value...
            .Datatype => blk: {
                // look for the type in the global builtin types

                const t = self.symbol_table.lookup_type(type_hint.value) orelse {
                    // TODO: return a proper error
                    std.debug.panic("Type hint not found", .{});
                };

                break :blk t;
            },
            else => {
                std.debug.panic("not implemented: other datatypes during typechecking", .{});
            },
        } else Type.Untyped;

        // check types
        if (!hinted_type.is_untyped()) {
            // Assert both the type hint and the actual type are the same
            if (!hinted_type.eql(&expression_type)) {
                // The types differ. Return an error

                const hinted_type_name = hinted_type.to_str();
                const expression_type_name = expression_type.to_str();

                var new_error = try self.err.create_and_append_error(
                    "Type mismatch in variable declaration",
                    node.datatype.?.start_pos,
                    node.datatype.?.end_pos(),
                );

                {
                    const err_msg = try std.fmt.allocPrint(self.err.allocator, "This variable declared type `{s}` here", .{hinted_type_name});
                    const err_msg_label = self.err.create_error_label_alloc(
                        err_msg,
                        node.datatype.?.start_pos,
                        node.datatype.?.end_pos(),
                    );
                    try new_error.add_label(err_msg_label);
                }

                {
                    const expression_range = .{ 0, 1 };
                    // const expression_range = node.expression.get_range();
                    const err_msg = try std.fmt.allocPrint(self.err.allocator, "But this expression has type `{s}`", .{expression_type_name});
                    const err_msg_label = self.err.create_error_label_alloc(
                        err_msg,
                        expression_range.@"0",
                        expression_range.@"1",
                    );
                    try new_error.add_label(err_msg_label);
                }

                return VisitorError.SemanticError;
            }
        }

        // assign types
        const symbol_name = node.identifier.value;
        if (!self.scope.has(symbol_name)) {
            // the node was not inserted  on a previous phase?
            std.debug.panic("A symbol was not on the symbol table during typechecking...", .{});
        }

        try self.scope.insert(
            symbol_name,
            .{
                .t = expression_type,
                .location = .{
                    .start = node.identifier.start_pos,
                    .end = node.identifier.start_pos + node.identifier.value.len,
                },
            },
        );
    }

    pub fn visitor(self: *TypecheckerVisitor) Visitor {
        return Visitor{
            .ptr = self,
            .visitStatementFn = visitStatement,
            .visitVariableBindingFn = visitVariableBinding,
        };
    }
};

test "should not fail" {
    try std.testing.expect(true);
}
