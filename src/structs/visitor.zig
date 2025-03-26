const std = @import("std");
const syntax = @import("syntax");

const structs = @import("semantics.zig");

const StringHashMap = std.StringHashMapUnmanaged;
const Scope = structs.Scope;
const Symbol = structs.Symbol;

const Statement = syntax.statement.Statement;

// Visitor interface for traversing the AST.
pub const Visitor = struct {
    ptr: *anyopaque,

    // Define ast nodes to visit
    visitStatementFn: *const fn (self: *anyopaque, node: *const Statement) void,

    // Define visit methods for each ast node
    pub fn visitStatement(self: Visitor, node: *const Statement) void {
        self.visitStatementFn(self.ptr, node);
    }
};

const SymbolCollectorVisitor = struct {
    scope: *Scope,

    fn visitStatement(ptr: *anyopaque, node: *const Statement) void {
        const self: *SymbolCollectorVisitor = @ptrCast(@alignCast(ptr));
        _ = node;
        _ = self;

        // todo: actually visit...
        std.debug.print(":o \n", .{});
    }

    fn visitor(self: *SymbolCollectorVisitor) Visitor {
        return Visitor{
            .ptr = self,
            .visitStatementFn = visitStatement,
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

    var visitor = symbolVisitor.visitor();
    visitor.visitStatement(undefined);
}
