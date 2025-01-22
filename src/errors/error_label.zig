const std = @import("std");

pub const ErrorLabel = struct {
    message: []const u8,
    start: usize,
    end: usize,

    /// Converts this struct into JSON
    pub fn json(self: ErrorLabel, alloc: std.mem.Allocator) ![]u8 {
        return try std.json.stringifyAlloc(alloc, .{
            .message = self.message,
            .start = self.start,
            .end = self.end,
        }, .{});
    }
};

test "should serialize" {
    const label = ErrorLabel{
        .message = "Error",
        .start = 5,
        .end = 6,
    };
    const json_str = try label.json(std.testing.allocator);
    defer std.testing.allocator.free(json_str);

    const expected =
        \\{"message":"Error","start":5,"end":6}
    ;
    try std.testing.expectEqualStrings(expected, json_str);
}

test "should handle special characters" {
    const label = ErrorLabel{
        .message = "Error\"with\"quotes",
        .start = 0,
        .end = 1,
    };
    const json_str = try label.json(std.testing.allocator);
    defer std.testing.allocator.free(json_str);

    const expected =
        \\{"message":"Error\"with\"quotes","start":0,"end":1}
    ;
    try std.testing.expectEqualStrings(expected, json_str);
}

test "should serialize empty message" {
    const label = ErrorLabel{
        .message = "",
        .start = 0,
        .end = 0,
    };
    const json_str = try label.json(std.testing.allocator);
    defer std.testing.allocator.free(json_str);

    const expected =
        \\{"message":"","start":0,"end":0}
    ;
    try std.testing.expectEqualStrings(expected, json_str);
}
