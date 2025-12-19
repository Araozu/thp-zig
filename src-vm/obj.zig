const std = @import("std");

pub const ObjType = enum(u8) {
    String,
};

/// A dynamic reference type, for data that lives on the heap.
pub const Obj = struct {
    t: ObjType,

    pub fn as_string(self: *const Obj) *ObjString {
        return @ptrCast(self);
    }
};

pub const ObjString = struct {
    base: Obj,
    bytes: union(enum) {
        /// The string is stored in the constant data segment.
        constant: []u8,
        /// The string is stored in the heap. Owned by the ObjString.
        heap: []u8,
    },

    const Self = @This();

    /// Dupes the string bytes
    pub fn init_dynamic(self: *Self, allocator: std.mem.Allocator, bytes: []const u8) !void {
        self.* = .{
            .base = .{ .t = ObjType.String },
            .bytes = .{ .heap = try allocator.dupe(u8, bytes) },
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        switch (self.bytes) {
            .heap => |h| {
                allocator.free(h);
            },
            .constant => {},
        }
    }
};
