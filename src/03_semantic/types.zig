const std = @import("std");

const StringHashMap = std.StringHashMapUnmanaged;

pub const SymbolInfo = struct {
    t: Type,
    location: struct {
        start: usize,
        end: usize,
    },
};

pub const Type = enum {
    Untyped,
    Int,
    Float,
    String,
    // TODO: function types, generic types, container types

    pub fn to_str(self: *const Type) []const u8 {
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
    symbols: StringHashMap(SymbolInfo),
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

    pub fn insert(self: *Scope, name: []const u8, insert_value: SymbolInfo) !void {
        try self.symbols.put(self.allocator, name, insert_value);
    }

    pub fn has(self: *Scope, name: []const u8) bool {
        return self.symbols.contains(name);
    }

    pub fn get(self: *Scope, name: []const u8) ?SymbolInfo {
        // Check current scope
        const t = self.symbols.get(name);
        if (t != null) {
            return t;
        }
        if (self.parent) |parent| {
            return parent.get(name);
        }
        return null;
    }

    pub fn symbols_json(self: *Scope, writer: anytype) !void {
        // iterate over the symbols, write as JSON
        var it = self.symbols.iterator();

        try writer.writeAll("[");
        var is_first = true;
        while (it.next()) |_entry| {
            const entry_name = _entry.key_ptr;
            const entry = _entry.value_ptr.*;

            if (!is_first) {
                try writer.writeAll(",");
            }
            // try std.json.stringify(entry, .{}, writer);
            try std.json.stringify(
                .{
                    .symbol_name = entry_name,
                    .t = entry.t.to_str(),
                    .start = entry.location.start,
                    .end = entry.location.end,
                },
                .{},
                writer,
            );

            is_first = false;
        }
        try writer.writeAll("]");
    }

    pub fn deinit(self: *Scope) void {
        // cleanup children scopes
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        // cleanup children arraylist
        self.children.deinit(self.allocator);

        // clean up symbols
        self.symbols.deinit(self.allocator);
    }
};

test "should insert a symbol" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    try scope.insert("foo", .{ .t = Type.Int, .location = .{ .start = 0, .end = 0 } });
}

test "should test if a scope has a symbol" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    try scope.insert("foo", .{ .t = Type.Int, .location = .{ .start = 0, .end = 0 } });
    try std.testing.expectEqual(true, scope.has("foo"));
}

test "should test if a scope has a symbol 2" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    try scope.insert("foo", .{ .t = Type.Int, .location = .{ .start = 0, .end = 0 } });
    try std.testing.expectEqual(false, scope.has("bar"));
}

test "should retrieve a symbol" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    try scope.insert("foo", .{ .t = Type.Int, .location = .{ .start = 0, .end = 0 } });
    const out = scope.get("foo") orelse std.debug.panic("foo is null", .{});
    try std.testing.expectEqual(Type.Int, out.t);
}

test "should create a child scope" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    var child_scope = try scope.from_parent();
    try child_scope.insert("foo", .{ .t = Type.Int, .location = .{ .start = 0, .end = 0 } });
}

test "should create a child scope 2" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    var child_scope = try scope.from_parent();
    try child_scope.insert("foo", .{ .t = Type.Int, .location = .{ .start = 0, .end = 0 } });

    var child_child_scope = try child_scope.from_parent();
    try child_child_scope.insert("bar", .{ .t = Type.Float, .location = .{ .start = 0, .end = 0 } });
}

test "should test if a scope or parent scope has a symbol" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    try scope.insert("foo", .{ .t = Type.Float, .location = .{ .start = 0, .end = 0 } });

    var child_scope = try scope.from_parent();
    try child_scope.insert("bar", .{ .t = Type.Float, .location = .{ .start = 0, .end = 0 } });

    var child_child_scope = try child_scope.from_parent();

    const bar = child_child_scope.get("bar") orelse std.debug.panic("bar is null", .{});
    try std.testing.expectEqual(Type.Float, bar.t);

    const foo = child_child_scope.get("foo") orelse std.debug.panic("foo is null", .{});
    try std.testing.expectEqual(Type.Float, foo.t);
}
