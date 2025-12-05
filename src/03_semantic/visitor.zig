const std = @import("std");
const syntax = @import("syntax");
const types = @import("types.zig");

const StringHashMap = std.StringHashMapUnmanaged;
const Scope = types.Scope;

const Statement = syntax.Statement;
const VariableBinding = syntax.VariableBinding;

pub const VisitorError = error{
    OutOfMemory,
    SemanticError,
};

// Creates a visitor with custom return types
pub fn Visitor(comptime ReturnType: type) type {
    return struct {
        ptr: *anyopaque,

        // Define ast nodes to visit
        visitStatementFn: *const fn (self: *anyopaque, node: *const Statement) VisitorError!ReturnType,
        visitExpressionFn: *const fn (self: *anyopaque, node: *const syntax.PrattExpression) VisitorError!ReturnType,
        visitVariableBindingFn: *const fn (self: *anyopaque, node: *const VariableBinding) VisitorError!ReturnType,

        // Define visit methods for each ast node
        pub fn visitStatement(self: Visitor(ReturnType), node: *const Statement) VisitorError!ReturnType {
            return try self.visitStatementFn(self.ptr, node);
        }

        pub fn visitVariableBinding(self: Visitor(ReturnType), node: *const VariableBinding) VisitorError!ReturnType {
            return try self.visitVariableBindingFn(self.ptr, node);
        }

        pub fn visitExpression(self: Visitor(ReturnType), node: *const syntax.PrattExpression) VisitorError!ReturnType {
            return try self.visitExpressionFn(self.ptr, node);
        }
    };
}
