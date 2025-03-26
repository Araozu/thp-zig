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
    scope: *Scope,
};

pub const Scope = struct {
    symbols: std.StringHashMapUnmanaged(*Symbol),
    parent: ?*Scope,
};
