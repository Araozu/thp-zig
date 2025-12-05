const std = @import("std");

pub const ObjType = enum(u64) {
    String,
};

/// A dynamic reference type, for data that lives on the heap.
pub const Obj = extern struct {
    t: ObjType,

    pub fn as_string(self: *const Obj) *ObjString {
        return @ptrCast(self);
    }
};

pub const ObjString = extern struct {
    base: Obj,
    bytes: union(enum) {
        /// The string is stored in the constant data segment.
        constant: []u8,
        /// The string is stored in the heap. Owned by the ObjString.
        heap: []u8,
    },

    pub fn init(allocator: std.mem.Allocator) !ObjString {
        _ = allocator;
        //
        return .{};
    }
};
