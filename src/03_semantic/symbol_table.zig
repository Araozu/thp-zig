const std = @import("std");

const types = @import("./types.zig");

const Scope = types.Scope;
const Type = types.Type;

pub const SymbolTable = struct {
    allocator: std.mem.Allocator,
    scope: Scope,
    builtin_types: std.StringHashMapUnmanaged(Type),

    pub fn init(self: *SymbolTable, allocator: std.mem.Allocator) !void {
        self.* = .{
            .allocator = allocator,
            .scope = Scope.init(allocator),
            .builtin_types = .empty,
        };

        // Insert builtin types
        try self.builtin_types.put(self.allocator, "Int", Type.Int);
        try self.builtin_types.put(self.allocator, "Float", Type.Float);
        try self.builtin_types.put(self.allocator, "String", Type.String);
        try self.builtin_types.put(self.allocator, "Bool", Type.Bool);

        // Builtin functions

        const type_ref = try allocator.create(Type);
        type_ref.* = Type.Unit;

        try self.builtin_types.put(self.allocator, "print", Type{
            .Function = .{
                .params = &.{},
                .return_t = type_ref,
            },
        });
    }

    pub fn lookup_type(self: *const SymbolTable, type_name: []const u8) ?Type {
        return self.builtin_types.get(type_name);
    }

    pub fn deinit(self: *SymbolTable) void {
        var scope_ref = &self.scope;
        self.builtin_types.deinit(self.allocator);
        scope_ref.deinit();

        // FIXME: release the type's Function's `return_t`
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
