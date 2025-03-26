const std = @import("std");
const syntax = @import("syntax");

const visitor = @import("visitor.zig");
const SymbolVisitor = @import("./visitors/symbol_visitor.zig").SymbolCollectorVisitor;
const types = @import("types.zig");

const ASTModule = syntax.Module;

const HashMap = std.StringHashMapUnmanaged;
const SymbolTable = types.SymbolTable;
const Symbol = types.Symbol;
const Scope = types.Scope;
pub const Visitor = visitor.Visitor;

pub fn semantic_analysis(ast: *const ASTModule) void {
    const symbols_hm: HashMap(*Symbol) = .empty;

    var global_scope = Scope{
        .symbols = symbols_hm,
        .parent = null,
    };
    const symbol_table = SymbolTable{
        .scope = &global_scope,
    };

    _ = symbol_table;

    // Symbol collection
    // Iterate over the AST

    var symbol_visitor = SymbolVisitor.init(&global_scope);
    const v = symbol_visitor.visitor();
    for (ast.statements.items) |*statement| {
        statement.accept(&v);
    }

    // Scope building
    // Name resolution
    // Type checking
    // Control flow analysis
    // Constant evaluation
}
