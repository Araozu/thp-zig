const std = @import("std");

const StringHashMap = std.StringHashMapUnmanaged;

pub const Type = enum {
    Untyped,
    Int,
    Float,
    String,
    // TODO: function types, generic types, container types

    pub fn to_str(self: *Type) []const u8 {
        return switch (self.*) {
            .Untyped => "<untyped>",
            .Int => "Int",
            .Float => "Float",
            .String => "String",
        };
    }
};

pub const SymbolTable = struct {
    scope: *Scope,
};

pub const Scope = struct {
    symbols: StringHashMap(Type),
    parent: ?*Scope,

    pub fn from_parent(parent: *Scope) Scope {
        return Scope{
            .symbols = .empty,
            .parent = parent,
        };
    }

    pub fn insert(self: *Scope, alloc: std.mem.Allocator, name: []const u8, t: Type) !void {
        try self.symbols.put(alloc, name, t);
    }

    pub fn has(self: *Scope, name: []const u8) bool {
        return self.symbols.contains(name);
    }
};
