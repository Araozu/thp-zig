const std = @import("std");
const m_type_info = @import("type_info.zig");
const m_types = @import("types.zig");
const m_symbol_table = @import("symbol_table.zig");

const TypeMap = m_type_info.TypeInfoMap;
const Type = m_types.Type;

/// Stores semantic context information for the compiler.
///
/// Currently only holds a map of AST ids to their inferred types.
pub const SemanticContext = struct {
    type_map: TypeMap,
    allocator: std.mem.Allocator,
    symbol_table: *const m_symbol_table.SymbolTable,
    local_count: u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, symbol_table: *const m_symbol_table.SymbolTable) Self {
        return .{
            .type_map = .empty,
            .allocator = allocator,
            .local_count = 0,
            .symbol_table = symbol_table,
        };
    }

    pub fn set_type(self: *Self, ast_id: u64, t: Type) !void {
        try self.type_map.put(self.allocator, ast_id, .{ .computed_type = t });
    }

    pub fn deinit(self: *SemanticContext) void {
        self.type_map.deinit(self.allocator);
    }
};
