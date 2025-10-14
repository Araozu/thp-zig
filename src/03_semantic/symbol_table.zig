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
    }

    pub fn deinit(self: *SymbolTable) void {
        var scope_ref = &self.scope;
        self.builtin_types.deinit(self.allocator);
        scope_ref.deinit();
    }
};
