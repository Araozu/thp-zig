const std = @import("std");
const structs = @import("structs");

const HashMap = std.StringHashMapUnmanaged;
const SymbolTable = structs.semantics.SymbolTable;
const Symbol = structs.semantics.Symbol;
const Scope = structs.semantics.Scope;

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

test {
    std.testing.refAllDecls(@This());
}
