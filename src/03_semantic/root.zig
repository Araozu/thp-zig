const std = @import("std");

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
    // TODO: ??
}

test {
    std.testing.refAllDecls(@This());
}
