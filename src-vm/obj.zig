const std = @import("std");

pub const ObjType = enum(u8) {
    String,
};

/// A dynamic reference type, for data that lives on the heap.
pub const Obj = struct {
    t: ObjType,
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

    /// Inits the ObjString from 2 slices, concatenated.
    pub fn init_dynamic_from_2(self: *Self, allocator: std.mem.Allocator, bytes_1: []const u8, bytes_2: []const u8) !void {
        const slices: [2][]const u8 = .{ bytes_1, bytes_2 };
        const new_str = try std.mem.concat(allocator, u8, &slices);

        self.* = .{
            .base = .{ .t = ObjType.String },
            .bytes = .{ .heap = new_str },
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
