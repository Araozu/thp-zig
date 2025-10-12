const std = @import("std");
const lexic = @import("lexic");
const syntax = @import("syntax");
const context = @import("context");

const types = @import("../../types.zig");
const visitor = @import("../../visitor.zig");

const TokenType = lexic.TokenType;
const ErrorCtx = context.ErrorContext;
const StringHashMap = std.StringHashMapUnmanaged;
const Scope = types.Scope;
const Type = types.Type;
const Visitor = visitor.Visitor;
const VisitorError = visitor.VisitorError;

const Statement = syntax.Statement;
const VariableBinding = syntax.VariableBinding;

pub const TypecheckerVisitor = struct {
    scope: *Scope,
    alloc: std.mem.Allocator,
    err: *ErrorCtx,

    pub fn init(
        alloc: std.mem.Allocator,
        s: *Scope,
        err: *ErrorCtx,
    ) TypecheckerVisitor {
        return TypecheckerVisitor{
            .scope = s,
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
        const expression_type = switch (node.expression.*) {
            .float => Type.Float,
            .int => Type.Int,
            .string => Type.String,
            .identifier => {
                std.debug.panic("Not implemented: get type of an identifier.", .{});
            },
            .paren => {
                std.debug.panic("Not implemented: get type of expression within paren.", .{});
            },
            // else => Type.Untyped,
        };

        // get the type of the type hint, if any
        const hinted_type = if (node.datatype) |type_hint| switch (type_hint.token_type) {
            // Should match against Datatype and parse its value...
            .Datatype => {
                // TODO: Match token value against common datatypes?
                std.debug.panic("not implemented: type hints in a variable declaration", .{});
            },
            else => {
                std.debug.panic("not implemented: other datatypes during typechecking", .{});
            },
        } else Type.Untyped;

        // check types
        if (hinted_type != Type.Untyped) {
            // Assert both the type hint and the actual type are the same
            if (hinted_type != expression_type) {
                // The types differ. Return an error

                // FIXME: add proper error indicators, get already inserted symbol position
                const error_start = 0;
                const error_end = 0;
                var new_error = try self.err.create_and_append_error("Mismatched types", error_start, error_end);
                try new_error.add_label(self.err.create_error_label("The declared type and the received type are not the same", error_start, error_end));

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
