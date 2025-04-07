const std = @import("std");
const syntax = @import("syntax");
const types = @import("types.zig");

const StringHashMap = std.StringHashMapUnmanaged;
const Scope = types.Scope;

const Statement = syntax.Statement;
const VariableBinding = syntax.VariableBinding;

pub const VisitorError = error{
    OutOfMemory,
};

// Visitor interface for traversing the AST.
pub const Visitor = struct {
    ptr: *anyopaque,

    // Define ast nodes to visit
    visitStatementFn: *const fn (self: *anyopaque, node: *const Statement) VisitorError!void,
    visitVariableBindingFn: *const fn (self: *anyopaque, node: *const VariableBinding) VisitorError!void,

    // Define visit methods for each ast node
    pub fn visitStatement(self: Visitor, node: *const Statement) VisitorError!void {
        try self.visitStatementFn(self.ptr, node);
    }

    pub fn visitVariableBinding(self: Visitor, node: *const VariableBinding) VisitorError!void {
        try self.visitVariableBindingFn(self.ptr, node);
    }
};
