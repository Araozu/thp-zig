const std = @import("std");

pub const Value = union(enum(u8)) {
    /// A concrete value. Caller must bitcast to the appropriate type.
    value: u64,
    /// A reference
    ref: usize,
};

pub fn print_value(value: Value) void {
    // std.debug.print("{d}", .{value});
    _ = value;
}
