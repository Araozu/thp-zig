const std = @import("std");

/// Holds information about errors generated during the compilation,
/// and pretty prints them.
pub const ErrorData = struct {
    reason: []const u8,
    start_position: usize,
    end_position: usize,

    pub fn init(
        target: *@This(),
        reason: []const u8,
        start_position: usize,
        end_position: usize,
    ) void {
        target.* = .{
            .reason = reason,
            .start_position = start_position,
            .end_position = end_position,
        };
    }

    pub fn print(self: *@This()) void {
        std.debug.print("Error: {s}\n", .{self.reason});
    }

    /// Does nothing at the moment
    pub fn deinit(self: *@This()) void {
        _ = self;
    }
};

test {
    std.testing.refAllDecls(@This());
}
