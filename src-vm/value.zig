const std = @import("std");
const m_obj = @import("obj.zig");

const Obj = m_obj.Obj;

pub const Value = union(enum(u8)) {
    /// A concrete value. Caller must bitcast to the appropriate type.
    value: u64,
    /// A reference
    ref: *Obj,
};

pub fn print_value(value: Value) void {
    // std.debug.print("{d}", .{value});
    _ = value;
}
