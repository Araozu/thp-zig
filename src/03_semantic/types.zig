const std = @import("std");

const symbol_table = @import("./symbol_table.zig");

const StringHashMap = std.StringHashMapUnmanaged;

/// Represents a slot in the registers of the VM
///
/// A slot can be either to a value or a reference.
pub const RegisterRef = union(enum) {
    /// A index to the value registers
    val: u8,
    /// A index to the reference registers
    ref: u8,

    pub fn as_val(self: RegisterRef) u8 {
        return switch (self) {
            .val => |v| v,
            .ref => @panic("Expected a Value register reference"),
        };
    }

    pub fn as_ref(self: RegisterRef) u8 {
        return switch (self) {
            .val => @panic("Expected a Value register reference"),
            .ref => |v| v,
        };
    }
};

pub const SymbolInfo = struct {
    t: Type,
    location: struct {
        start: usize,
        end: usize,
    },

    /// Registers the associated slot index for the symbol.
    slot_index: ?RegisterRef = null,

    const Self = @This();

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.t.deinit(allocator);
    }
};

pub const Type = union(enum) {
    // Special types
    Untyped,
    Unit,

    // Common types
    U8,
    I32,
    U32,
    I64,
    U64,
    F32,
    F64,
    Bool,
    String,

    /// Type assumes ownership of `return_t`.
    /// It **must** be `create`d with the same allocator passed to this `deinit`
    Function: struct {
        params: []const Type,
        return_t: *Type,
    },
    // TODO: generic types, container types

    const Self = @This();

    pub fn to_str(self: *const Self) []const u8 {
        return switch (self.*) {
            .Untyped => "<untyped>",
            .Unit => "<unit>",
            .U8 => "u8",
            .I32 => "i32",
            .U32 => "u32",
            .I64 => "i64",
            .U64 => "u64",
            .F32 => "f32",
            .F64 => "f64",
            .String => "String",
            .Bool => "bool",
            .Function => "Function",
        };
    }

    pub fn is_untyped(self: *const Self) bool {
        return switch (self.*) {
            .Untyped => true,
            else => false,
        };
    }

    pub fn is_primitive(self: *const Self) bool {
        return switch (self.*) {
            .U8, .I32, .U32, .I64, .U64, .F32, .F64, .Bool => true,
            else => false,
        };
    }

    pub fn eql(self: *const Self, to: *const Type) bool {
        if (@intFromEnum(self.*) != @intFromEnum(to.*)) {
            return false;
        }

        // FIXME: actually operate on the tags inner values
        // like when Array is implemented

        return true;
    }

    /// This method **destroys** owned data if neccesary.
    /// That data **must** be `create`d with the same `allocator`
    /// passed to this method
    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .Function => |f| {
                allocator.destroy(f.return_t);
            },
            else => {},
        }
    }
};

pub const Scope = struct {
    symbols: StringHashMap(SymbolInfo),
    parent: ?*Scope,
    allocator: std.mem.Allocator,
    children: std.ArrayListUnmanaged(*Scope),
    types: std.ArrayListUnmanaged(*Type),
    next_val_slot: u8,
    next_ref_slot: u8,

    pub fn init(allocator: std.mem.Allocator) Scope {
        return .{
            .symbols = .empty,
            .parent = null,
            .allocator = allocator,
            .children = .empty,
            .types = .empty,
            .next_val_slot = 0,
            .next_ref_slot = 0,
        };
    }

    const Self = @This();

    /// Creates a new scope from a parent
    /// Children scopes are meant to be created, used, and left alone.
    /// The root node is responsible for cleaning up all its children scopes.
    /// So, `deinit` should be called only on the root scope, not on any of its
    /// children, otherwise a double free will happen.
    pub fn from_parent(self: *Self) !*Scope {
        const child = try self.allocator.create(Scope);
        child.* = Scope{
            .symbols = .empty,
            .parent = self,
            .allocator = self.allocator,
            .children = .empty,
            .types = .empty,
        };
        errdefer self.allocator.destroy(child);

        try self.children.append(self.allocator, child);
        return child;
    }

    /// Inserts a symbol into the current scope, overwriting any existing symbol with the same name.
    pub fn insert(self: *Self, name: []const u8, insert_value: SymbolInfo) !void {
        try self.symbols.put(self.allocator, name, insert_value);
    }

    pub fn has(self: *Self, name: []const u8) bool {
        return self.symbols.contains(name);
    }

    pub fn get(self: *const Self, name: []const u8) ?SymbolInfo {
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

    pub fn symbols_json(self: *Self, writer: anytype) !void {
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
            try std.json.Stringify.value(
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

    pub fn deinit(self: *Self) void {
        // deinit all scope types
        var iter = self.symbols.iterator();
        while (iter.next()) |symbol| {
            symbol.value_ptr.deinit(self.allocator);
        }

        // cleanup children scopes
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }

        // cleanup children arraylist
        self.children.deinit(self.allocator);

        // clean up symbols
        self.symbols.deinit(self.allocator);

        // clean up types
        self.types.deinit(self.allocator);
    }
};

test "should insert a symbol" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    try scope.insert("foo", .{ .t = Type.I64, .location = .{ .start = 0, .end = 0 } });
}

test "should test if a scope has a symbol" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    try scope.insert("foo", .{ .t = Type.I64, .location = .{ .start = 0, .end = 0 } });
    try std.testing.expectEqual(true, scope.has("foo"));
}

test "should test if a scope has a symbol 2" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    try scope.insert("foo", .{ .t = Type.I64, .location = .{ .start = 0, .end = 0 } });
    try std.testing.expectEqual(false, scope.has("bar"));
}

test "should retrieve a symbol" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    try scope.insert("foo", .{ .t = Type.I64, .location = .{ .start = 0, .end = 0 } });
    const out = scope.get("foo") orelse std.debug.panic("foo is null", .{});
    try std.testing.expectEqual(Type.I64, out.t);
}

test "should create a child scope" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    var child_scope = try scope.from_parent();
    try child_scope.insert("foo", .{ .t = Type.I64, .location = .{ .start = 0, .end = 0 } });
}

test "should create a child scope 2" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    var child_scope = try scope.from_parent();
    try child_scope.insert("foo", .{ .t = Type.I64, .location = .{ .start = 0, .end = 0 } });

    var child_child_scope = try child_scope.from_parent();
    try child_child_scope.insert("bar", .{ .t = Type.F64, .location = .{ .start = 0, .end = 0 } });
}

test "should test if a scope or parent scope has a symbol" {
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();

    try scope.insert("foo", .{ .t = Type.F64, .location = .{ .start = 0, .end = 0 } });

    var child_scope = try scope.from_parent();
    try child_scope.insert("bar", .{ .t = Type.F64, .location = .{ .start = 0, .end = 0 } });

    var child_child_scope = try child_scope.from_parent();

    const bar = child_child_scope.get("bar") orelse std.debug.panic("bar is null", .{});
    try std.testing.expectEqual(Type.F64, bar.t);

    const foo = child_child_scope.get("foo") orelse std.debug.panic("foo is null", .{});
    try std.testing.expectEqual(Type.F64, foo.t);
}
