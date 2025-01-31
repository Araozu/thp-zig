const std = @import("std");

/// Compiler wide state about.
/// For now only stores errors generated
pub const CompilerContext = struct {
    allocator: std.mem.Allocator,
    errors: std.ArrayList(ErrorData),

    pub fn init(allocator: std.mem.Allocator) CompilerContext {
        return .{
            .allocator = allocator,
            .errors = std.ArrayList(ErrorData).init(allocator),
        };
    }

    pub fn deinit(self: *CompilerContext) void {
        self.errors.deinit();
    }
};

pub const ErrorData = struct {
    /// A high level reason why the error occured
    reason: []const u8,
    /// A message with direct instructions to solve the error
    help: ?[]const u8,
    /// The absolute position from where the faulty code starts
    start_position: usize,
    /// The absolute position where the faulty code ends
    end_position: usize,
    /// A list of detailed messages about the error
    labels: std.ArrayList(ErrorLabel),
};

pub const ErrorLabel = struct {
    message: union(enum) {
        static: []const u8,
        dynamic: []u8,
    },
    start: usize,
    end: usize,
};
