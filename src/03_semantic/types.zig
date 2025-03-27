const std = @import("std");

const StringHashMap = std.StringHashMapUnmanaged;

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
    symbols: StringHashMap(*Symbol),
    parent: ?*Scope,

    pub fn from_parent(parent: *Scope) Scope {
        return Scope{
            .symbols = .empty,
            .parent = parent,
        };
    }
};
