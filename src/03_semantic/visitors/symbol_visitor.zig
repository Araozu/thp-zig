const std = @import("std");
const syntax = @import("syntax");
const context = @import("context");

const types = @import("../types.zig");
const visitor = @import("../visitor.zig");

const ErrorCtx = context.ErrorContext;
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
    err: *ErrorCtx,

    pub fn init(
        alloc: std.mem.Allocator,
        s: *Scope,
        err: *ErrorCtx,
    ) SymbolCollectorVisitor {
        return SymbolCollectorVisitor{
            .scope = s,
            .alloc = alloc,
            .err = err,
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
            var new_error = try self.err.create_and_append_error("Semantic error!!", 0, 0);
            try new_error.add_label(self.err.create_error_label("This symbol has already been declared on the current scope", 0, 0));

            return VisitorError.SemanticError;
        }

        self.scope.insert(variable_name, Type.Untyped) catch {
            return VisitorError.OutOfMemory;
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
