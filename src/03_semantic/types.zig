const std = @import("std");

const StringHashMap = std.StringHashMapUnmanaged;

pub const Type = enum {
    Int,
    Float,
    String,
    // TODO: function types, generic types, container types
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
        // FIXME: !! actually receive and use an allocator
        try self.symbols.put(alloc, name, t);
    }
};
