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
    allocator: std.mem.Allocator,
    children: std.ArrayListUnmanaged(*Scope),

    pub fn init(allocator: std.mem.Allocator) Scope {
        return Scope{
            .symbols = .empty,
            .parent = null,
            .allocator = allocator,
            .children = .empty,
        };
    }

    /// Creates a new scope from a parent
    /// Children scopes are meant to be created, used, and left alone.
    /// The root node is responsible for cleaning up all its children scopes.
    /// So, `deinit` should be called only on the root scope, not on any of its
    /// children, otherwise a double free will happen.
    pub fn from_parent(self: *Scope) !*Scope {
        const child = try self.allocator.create(Scope);
        child.* = Scope{
            .symbols = .empty,
            .parent = self,
            .allocator = self.allocator,
            .children = .empty,
        };
        errdefer self.allocator.destroy(child);

        try self.children.append(self.allocator, child);
        return child;
    }

    pub fn insert(self: *Scope, name: []const u8, t: Type) !void {
        try self.symbols.put(self.allocator, name, t);
    }

    pub fn has(self: *Scope, name: []const u8) bool {
        return self.symbols.contains(name);
    }

    pub fn get(self: *Scope, name: []const u8) ?Type {
        return self.symbols.get(name);
    }

    pub fn deinit(self: *Scope) void {
        self.symbols.deinit(self.allocator);
    }
};

test "should insert a symbol" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    try scope.insert("foo", Type.Int);
}

test "should test if a scope has a symbol" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    try scope.insert("foo", Type.Int);
    try std.testing.expectEqual(true, scope.has("foo"));
}

test "should test if a scope has a symbol 2" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    try scope.insert("foo", Type.Int);
    try std.testing.expectEqual(false, scope.has("bar"));
}

test "should retrieve a symbol" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    try scope.insert("foo", Type.Int);
    const out = scope.get("foo") orelse std.debug.panic("foo is null", .{});
    try std.testing.expectEqual(Type.Int, out);
}

test "should create a child scope" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    var child_scope = try scope.from_parent();
    try child_scope.insert("foo", Type.Int);
}
