const std = @import("std");
const m_types = @import("types.zig");

const Type = m_types.Type;

pub const TypeInfo = struct {
    computed_type: Type,
};

pub const U64Context = struct {
    const Self = @This();

    pub fn hash(self: *const Self, key: u64) u64 {
        _ = self;
        return key;
    }

    pub fn eql(self: *const Self, a: u64, b: u64) bool {
        _ = self;
        return a == b;
    }
};

pub const TypeInfoMap = std.hash_map.HashMapUnmanaged(u64, TypeInfo, U64Context, 80);
