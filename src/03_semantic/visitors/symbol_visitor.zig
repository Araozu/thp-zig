const std = @import("std");
const syntax = @import("syntax");

const types = @import("../types.zig");
const visitor = @import("../visitor.zig");

const StringHashMap = std.StringHashMapUnmanaged;
const Scope = types.Scope;
const Type = types.Type;
const Visitor = visitor.Visitor;
const VisitorError = visitor.VisitorError;

const Statement = syntax.Statement;
const VariableBinding = syntax.VariableBinding;

pub const SymbolCollectorVisitor = struct {
    scope: *Scope,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, s: *Scope) SymbolCollectorVisitor {
        return SymbolCollectorVisitor{
            .scope = s,
            .alloc = alloc,
        };
    }

    pub fn visitStatement(ptr: *anyopaque, node: *const Statement) VisitorError!void {
        const self: *SymbolCollectorVisitor = @ptrCast(@alignCast(ptr));

        switch (node.value) {
            .variableBinding => |b| {
                try b.accept(&self.visitor());
            },
        }
    }

    pub fn visitVariableBinding(ptr: *anyopaque, node: *const VariableBinding) VisitorError!void {
        const self: *SymbolCollectorVisitor = @ptrCast(@alignCast(ptr));

        const variable_name = node.identifier.value;
        if (self.scope.has(variable_name)) {
            // another symbol is already declared
            @panic("Symbol already declared");
        }

        self.scope.insert(variable_name, Type.Untyped) catch {
            @panic("memory error :c");
        };
    }

    pub fn visitor(self: *SymbolCollectorVisitor) Visitor {
        return Visitor{
            .ptr = self,
            .visitStatementFn = visitStatement,
            .visitVariableBindingFn = visitVariableBinding,
        };
    }
};
