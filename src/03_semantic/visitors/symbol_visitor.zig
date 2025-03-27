const std = @import("std");
const syntax = @import("syntax");

const types = @import("../types.zig");
const visitor = @import("../visitor.zig");

const StringHashMap = std.StringHashMapUnmanaged;
const Scope = types.Scope;
const Symbol = types.Symbol;
const Visitor = visitor.Visitor;

const Statement = syntax.Statement;
const VariableBinding = syntax.VariableBinding;

pub const SymbolCollectorVisitor = struct {
    scope: *Scope,

    pub fn init(s: *Scope) SymbolCollectorVisitor {
        return SymbolCollectorVisitor{
            .scope = s,
        };
    }

    pub fn visitStatement(ptr: *anyopaque, node: *const Statement) void {
        const self: *SymbolCollectorVisitor = @ptrCast(@alignCast(ptr));

        switch (node.value) {
            .variableBinding => |b| {
                // just delegate for now
                const v = self.visitor();
                b.accept(&v);
            },
        }
    }

    pub fn visitVariableBinding(ptr: *anyopaque, node: *const VariableBinding) void {
        const self: *SymbolCollectorVisitor = @ptrCast(@alignCast(ptr));
        _ = self;
        _ = node;

        std.debug.print("OMG! delegated VISITOR!!!\n", .{});
    }

    pub fn visitor(self: *SymbolCollectorVisitor) Visitor {
        return Visitor{
            .ptr = self,
            .visitStatementFn = visitStatement,
            .visitVariableBindingFn = visitVariableBinding,
        };
    }
};

test "should work" {
    var hm: StringHashMap(*Symbol) = .empty;
    defer hm.deinit(std.testing.allocator);

    var sc = Scope{
        .symbols = hm,
        .parent = null,
    };
    var symbolVisitor = SymbolCollectorVisitor{
        .scope = &sc,
    };

    var my_visitor = symbolVisitor.visitor();
    my_visitor.visitStatement(undefined);

    // ast nodes
    // for (nodes) |node| {
    //   switch (node.type) {
    //     .Statement => |s| {
    //       s.accept(visitor)
    //     }
    //   }
    // }
}

test {
    std.testing.refAllDecls(@This());
}
