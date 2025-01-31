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

    /// Appends a new error to the compiler context
    /// and returns a handle to the just created error
    pub fn create_and_append_error(
        self: *CompilerContext,
        reason: []const u8,
        start_position: usize,
        end_position: usize,
    ) !*ErrorData {
        var new_error = ErrorData{
            .reason = reason,
            .start_position = start_position,
            .end_position = end_position,
            .labels = std.ArrayList(ErrorLabel).init(self.allocator),
            .help = null,
        };

        try self.errors.append(new_error);
        return &new_error;
    }

    /// Creates a new ErrorLabel with a static message.
    /// This error is meant to be added to a ErrorData,
    /// and will be cleaned automatically
    pub fn create_error_label(
        self: *CompilerContext,
        message: []const u8,
        start: usize,
        end: usize,
    ) ErrorLabel {
        _ = self;
        return .{
            .message = .{ .static = message },
            .start = start,
            .end = end,
        };
    }

    pub fn deinit(self: *CompilerContext) void {
        for (self.errors.items) |*error_item| {
            error_item.deinit(self.allocator);
        }
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

    pub fn add_label(self: *ErrorData, label: *ErrorLabel) !void {
        try self.labels.append(label.*);
    }

    /// Sets the help message of this error.
    pub fn set_help(self: *ErrorData, help: []const u8) void {
        self.help = help;
    }

    pub fn deinit(self: *ErrorData, allocator: std.mem.Allocator) void {
        // Clean any labels. Those are assumed to have been initialized
        // by the same allocator this function receives
        for (self.labels.items) |*label| {
            label.deinit(allocator);
        }
        self.labels.deinit();
    }
};

pub const ErrorLabel = struct {
    message: union(enum) {
        static: []const u8,
        dynamic: []u8,
    },
    start: usize,
    end: usize,

    pub fn deinit(self: *ErrorLabel, allocator: std.mem.Allocator) void {
        switch (self.message) {
            .static => {},
            .dynamic => |msg| allocator.free(msg),
        }
    }
};
