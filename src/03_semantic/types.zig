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
    const empty = Scope{ .symbols = .empty, .parent = null };

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

    pub fn get(self: *Scope, name: []const u8) ?Type {
        return self.symbols.get(name);
    }

    pub fn deinit(self: *Scope, allocator: std.mem.Allocator) void {
        self.symbols.deinit(allocator);
    }
};

test "should insert a symbol" {
    var scope: Scope = .empty;
    defer scope.deinit(std.testing.allocator);

    try scope.insert(std.testing.allocator, "foo", Type.Int);
}

test "should test if a scope has a symbol" {
    var scope: Scope = .empty;
    defer scope.deinit(std.testing.allocator);

    try scope.insert(std.testing.allocator, "foo", Type.Int);
    try std.testing.expectEqual(true, scope.has("foo"));
}

test "should test if a scope has a symbol 2" {
    var scope: Scope = .empty;
    defer scope.deinit(std.testing.allocator);

    try scope.insert(std.testing.allocator, "foo", Type.Int);
    try std.testing.expectEqual(false, scope.has("bar"));
}

test "should retrieve a symbol" {
    var scope: Scope = .empty;
    defer scope.deinit(std.testing.allocator);

    try scope.insert(std.testing.allocator, "foo", Type.Int);
    const out = scope.get("foo") orelse std.debug.panic("foo is null", .{});
    try std.testing.expectEqual(Type.Int, out);
}
