const std = @import("std");

const types = @import("./types.zig");

const Scope = types.Scope;
const Type = types.Type;

pub const SymbolTable = struct {
    allocator: std.mem.Allocator,
    scope: Scope,
    builtin_types: std.StringHashMapUnmanaged(Type),

    const Self = @This();

    pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
        self.* = .{
            .allocator = allocator,
            .scope = Scope.init(allocator),
            .builtin_types = .empty,
        };

        // Insert builtin types
        try self.builtin_types.put(allocator, "i64", Type.I64);
        try self.builtin_types.put(allocator, "f64", Type.F64);
        try self.builtin_types.put(allocator, "String", Type.String);
        try self.builtin_types.put(allocator, "bool", Type.Bool);

        // Builtin functions
        {
            const type_ref = try allocator.create(Type);
            type_ref.* = Type.Unit;
            try self.scope.symbols.put(allocator, "print", .{
                .t = Type{
                    .Function = .{
                        .params = &.{},
                        .return_t = type_ref,
                    },
                },
                .location = .{ .start = 0, .end = 1 },
                .slot_index = null,
            });
        }
        {
            const type_ref = try allocator.create(Type);
            type_ref.* = Type.Unit;
            try self.scope.symbols.put(allocator, "prints", .{
                .t = Type{
                    .Function = .{
                        .params = &.{},
                        .return_t = type_ref,
                    },
                },
                .location = .{ .start = 0, .end = 1 },
                .slot_index = null,
            });
        }
    }

    pub fn lookup_type(self: *const Self, type_name: []const u8) ?Type {
        return self.builtin_types.get(type_name);
    }

    pub fn deinit(self: *Self) void {
        var scope_ref = &self.scope;
        self.builtin_types.deinit(self.allocator);
        scope_ref.deinit();
    }
};

test "Should fetch a builtin type" {
    var symbol_table: SymbolTable = undefined;
    try symbol_table.init(std.testing.allocator);
    defer symbol_table.deinit();

    const type_name: []const u8 = "String";

    if (symbol_table.lookup_type(type_name)) |t| {
        try std.testing.expectEqual(t, Type.String);
    } else {
        try std.testing.expect(false);
    }
}
