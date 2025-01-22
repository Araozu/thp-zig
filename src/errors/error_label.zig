const std = @import("std");

pub const ErrorLabel = struct {
    message: []const u8,
    start: usize,
    end: usize,
};
