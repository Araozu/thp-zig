const std = @import("std");

const types = @import("./types.zig");

const Scope = types.Scope;
const Type = types.Type;

pub const SymbolTable = struct {
    allocator: std.mem.Allocator,
    scope: Scope,
    builtin_types: std.ArrayListUnmanaged(*Type),

    pub fn init(allocator: std.mem.Allocator) SymbolTable {
        return SymbolTable{
            .allocator = allocator,
            .scope = Scope.init(allocator),
            .builtin_types = .empty,
        };
    }

    pub fn deinit(self: *SymbolTable) void {
        var scope_ref = &self.scope;
        self.builtin_types.deinit(self.allocator);
        scope_ref.deinit();
    }
};
