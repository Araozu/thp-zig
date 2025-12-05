const std = @import("std");
const syntax = @import("syntax");
const ctx = @import("context");

const visitor = @import("visitor.zig");
const SymbolVisitor = @import("./visitors/symbol_visitor.zig").SymbolCollectorVisitor;
const TypecheckerVisitor = @import("./visitors/typechecker/typechecker_visitor.zig").TypecheckerVisitor;
const types = @import("types.zig");
const symbol_table_mod = @import("./symbol_table.zig");
const m_semantic_context = @import("./semantic_context.zig");

const ASTModule = syntax.Module;

const HashMap = std.StringHashMapUnmanaged;
pub const SymbolTable = symbol_table_mod.SymbolTable;
const Type = types.Type;
pub const Scope = types.Scope;
pub const Visitor = visitor.Visitor;
pub const VisitorError = visitor.VisitorError;
pub const SemanticContext = m_semantic_context.SemanticContext;

pub fn semantic_analysis(
    alloc: std.mem.Allocator,
    ast: *const ASTModule,
    err: *ctx.ErrorContext,
) VisitorError!void {
    var symbol_table: SymbolTable = undefined;
    try symbol_table.init(alloc);
    defer symbol_table.deinit();

    _ = try semantic_analysis_unmanaged(&symbol_table, alloc, ast, err);
}

pub fn semantic_analysis_unmanaged(
    symbol_table: *SymbolTable,
    alloc: std.mem.Allocator,
    ast: *const ASTModule,
    err: *ctx.ErrorContext,
) VisitorError!SemanticContext {
    var semantic_ctx = SemanticContext.init(alloc);
    errdefer semantic_ctx.deinit();

    // Symbol collection
    // Scope building
    // Iterate over the AST

    var symbol_visitor = SymbolVisitor.init(alloc, &symbol_table.scope, err);
    const v = symbol_visitor.visitor();
    for (ast.statements.items) |*statement| {
        try statement.accept(void, &v);
    }

    // Name resolution
    // Type checking
    var typechecker_visitor = TypecheckerVisitor.init(alloc, symbol_table, &symbol_table.scope, &semantic_ctx, err);
    const type_visitor = typechecker_visitor.visitor();
    for (ast.statements.items) |*statement| {
        _ = try statement.accept(Type, &type_visitor);
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

    return semantic_ctx;
}

test {
    std.testing.refAllDecls(@This());
}
