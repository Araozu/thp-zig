const std = @import("std");
const syntax = @import("syntax");
const ctx = @import("context");

const visitor = @import("visitor.zig");
const SymbolVisitor = @import("./visitors/symbol_visitor.zig").SymbolCollectorVisitor;
const TypecheckerVisitor = @import("./visitors/typechecker/typechecker_visitor.zig").TypecheckerVisitor;
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
) VisitorError!void {
    var global_scope = Scope.init(alloc);
    defer global_scope.deinit();

    var symbol_table = SymbolTable{
        .scope = &global_scope,
    };

    try semantic_analysis_unmanaged(&symbol_table, alloc, ast, err);
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
    var typechecker_visitor = TypecheckerVisitor.init(alloc, symbol_table.scope, err);
    const type_visitor = typechecker_visitor.visitor();
    for (ast.statements.items) |*statement| {
        try statement.accept(&type_visitor);
    }

    // Control flow analysis
    // Constant evaluation

    // Debugging
    // var hm_iterator = symbol_table.scope.symbols.iterator();
    //
    // while (hm_iterator.next()) |next_entry| {
    //     var symbol_info = next_entry.value_ptr.*;
    //     std.debug.print("analyzed:\n\t{s}: {s}\n", .{ next_entry.key_ptr.*, symbol_info.t.to_str() });
    //     std.debug.print("\tat {d}:{d}\n", .{ symbol_info.location.start, symbol_info.location.end });
    // }
}

test {
    std.testing.refAllDecls(@This());
}
