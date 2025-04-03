const std = @import("std");
const syntax = @import("syntax");

const types = @import("../types.zig");
const visitor = @import("../visitor.zig");

const StringHashMap = std.StringHashMapUnmanaged;
const Scope = types.Scope;
const Type = types.Type;
const Visitor = visitor.Visitor;

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

    pub fn visitStatement(ptr: *anyopaque, node: *const Statement) void {
        const self: *SymbolCollectorVisitor = @ptrCast(@alignCast(ptr));

        switch (node.value) {
            .variableBinding => |b| {
                b.accept(&self.visitor());
            },
        }
    }

    pub fn visitVariableBinding(ptr: *anyopaque, node: *const VariableBinding) void {
        const self: *SymbolCollectorVisitor = @ptrCast(@alignCast(ptr));

        const variable_name = node.identifier.value;
        if (self.scope.has(variable_name)) {
            // another symbol is already declared
            @panic("Symbol already declared");
        }

        self.scope.insert(self.alloc, variable_name, Type.Untyped) catch {
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

// test "should work" {
//     var hm: StringHashMap(Type) = .empty;
//     defer hm.deinit(std.testing.allocator);
//
//     var sc = Scope{
//         .symbols = hm,
//         .parent = null,
//     };
//     var symbolVisitor = SymbolCollectorVisitor{
//         .scope = &sc,
//         .alloc = std.testing.allocator,
//     };
//
//     var my_visitor = symbolVisitor.visitor();
//     my_visitor.visitStatement(undefined);
//
//     // ast nodes
//     // for (nodes) |node| {
//     //   switch (node.type) {
//     //     .Statement => |s| {
//     //       s.accept(visitor)
//     //     }
//     //   }
//     // }
// }

test {
    std.testing.refAllDecls(@This());
}
