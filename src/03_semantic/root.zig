const std = @import("std");
const visitor = @import("./visitor.zig");

pub const Type = union(enum) {
    Int,
    Float,
    String,
    // TODO: function types, generic types, container types
};

pub const Symbol = struct {
    name: []u8,
    type: Type,
};

pub const SymbolTable = struct {
    symbols: std.StringHashMap(*Symbol),
    parent: ?*SymbolTable,
};

pub fn semantic_analysis() void {
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

test "1" {
    const v = visitor.Visitor{
        .ptr = undefined,
        .visitStatementFn = undefined,
    };
    _ = v;
}
