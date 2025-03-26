const std = @import("std");
const syntax = @import("syntax");

const visitor = @import("visitor.zig");
const types = @import("types.zig");

const Statement = syntax.statement.Statement;

const HashMap = std.StringHashMapUnmanaged;
const SymbolTable = types.SymbolTable;
const Symbol = types.Symbol;
const Scope = types.Scope;
pub const Visitor = visitor.Visitor;

pub fn semantic_analysis() void {
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
    // Scope building
    // Name resolution
    // Type checking
    // Control flow analysis
    // Constant evaluation
}
