const std = @import("std");

pub const Value = u64;

pub fn print_value(value: Value) void {
    std.debug.print("{d}", .{value});
}
