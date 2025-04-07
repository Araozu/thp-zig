const std = @import("std");
const syntax = @import("syntax");

const visitor = @import("visitor.zig");
const SymbolVisitor = @import("./visitors/symbol_visitor.zig").SymbolCollectorVisitor;
const types = @import("types.zig");

const ASTModule = syntax.Module;

const HashMap = std.StringHashMapUnmanaged;
const SymbolTable = types.SymbolTable;
const Type = types.Type;
const Scope = types.Scope;
pub const Visitor = visitor.Visitor;
pub const VisitorError = visitor.VisitorError;

pub fn semantic_analysis(alloc: std.mem.Allocator, ast: *const ASTModule) void {
    var global_scope = Scope.init(alloc);
    defer global_scope.deinit();

    const symbol_table = SymbolTable{
        .scope = &global_scope,
    };

    // Symbol collection
    // Scope building
    // Iterate over the AST

    var symbol_visitor = SymbolVisitor.init(alloc, &global_scope);
    const v = symbol_visitor.visitor();
    for (ast.statements.items) |*statement| {
        statement.accept(&v);
    }

    // Name resolution
    // Type checking
    // Control flow analysis
    // Constant evaluation

    var hm_iterator = symbol_table.scope.symbols.iterator();

    while (hm_iterator.next()) |next| {
        std.debug.print("analyzed:\n\t{s}: {s}\n", .{ next.key_ptr.*, next.value_ptr.to_str() });
    }
}

test {
    std.testing.refAllDecls(@This());
}
