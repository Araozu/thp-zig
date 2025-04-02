const std = @import("std");
const syntax = @import("syntax");
const types = @import("types.zig");

const StringHashMap = std.StringHashMapUnmanaged;
const Scope = types.Scope;
const Symbol = types.Symbol;

const Statement = syntax.Statement;
const VariableBinding = syntax.VariableBinding;

// Visitor interface for traversing the AST.
pub const Visitor = struct {
    ptr: *anyopaque,

    // TODO: how to handle errors?
    // Define ast nodes to visit
    visitStatementFn: *const fn (self: *anyopaque, node: *const Statement) void,
    visitVariableBindingFn: *const fn (self: *anyopaque, node: *const VariableBinding) void,

    // Define visit methods for each ast node
    pub fn visitStatement(self: Visitor, node: *const Statement) void {
        self.visitStatementFn(self.ptr, node);
    }

    pub fn visitVariableBinding(self: Visitor, node: *const VariableBinding) void {
        self.visitVariableBindingFn(self.ptr, node);
    }
};
