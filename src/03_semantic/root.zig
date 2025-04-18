const std = @import("std");
const syntax = @import("syntax");
const ctx = @import("context");

const visitor = @import("visitor.zig");
const SymbolVisitor = @import("./visitors/symbol_visitor.zig").SymbolCollectorVisitor;
const types = @import("types.zig");

const ASTModule = syntax.Module;

const HashMap = std.StringHashMapUnmanaged;
pub const SymbolTable = types.SymbolTable;
const Type = types.Type;
pub const Scope = types.Scope;
pub const Visitor = visitor.Visitor;
pub const VisitorError = visitor.VisitorError;

pub fn semantic_analysis(
    alloc: std.mem.Allocator,
    ast: *const ASTModule,
    err: *ctx.ErrorContext,
) void {
    var global_scope = Scope.init(alloc);
    defer global_scope.deinit();

    var symbol_table = SymbolTable{
        .scope = &global_scope,
    };

    semantic_analysis_unmanaged(&symbol_table, alloc, ast, err);
}

pub fn semantic_analysis_unmanaged(
    symbol_table: *SymbolTable,
    alloc: std.mem.Allocator,
    ast: *const ASTModule,
    err: *ctx.ErrorContext,
) VisitorError!void {
    // Symbol collection
    // Scope building
    // Iterate over the AST

    var symbol_visitor = SymbolVisitor.init(alloc, symbol_table.scope, err);
    const v = symbol_visitor.visitor();
    for (ast.statements.items) |*statement| {
        try statement.accept(&v);
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
