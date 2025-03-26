const std = @import("std");
const syntax = @import("syntax");

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
    scope: *i32,

    fn visitStatement(ptr: *anyopaque, node: *const Statement) void {
        const self: *SymbolCollectorVisitor = @ptrCast(@alignCast(ptr));
        _ = node;

        // todo: actually visit...
        std.debug.print(":D {d}\n", .{self.scope.*});
    }

    fn visitor(self: *SymbolCollectorVisitor) Visitor {
        return Visitor{
            .ptr = self,
            .visitStatementFn = visitStatement,
        };
    }
};

test "should work" {
    var sc: i32 = 322;
    var symbolVisitor = SymbolCollectorVisitor{
        .scope = &sc,
    };

    var visitor = symbolVisitor.visitor();
    visitor.visitStatement(undefined);
}
