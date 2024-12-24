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

    /// Generates an error string. `alloc` is used to create the string,
    /// the caller should call `free` on the returning slice.
    pub fn get_error_str(self: *@This(), source_code: []const u8, alloc: std.mem.Allocator) ![]u8 {
        const faulty_line = get_line(source_code, self.start_position);

        const error_message = try std.fmt.allocPrint(alloc,
            \\Error: {s}
            \\{s}
        , .{ self.reason, faulty_line });

        return error_message;
    }

    // TODO:
    // - transform absolute position into line:column
    // - Get previous, current and next line
    // - Display message

    /// Does nothing at the moment
    pub fn deinit(self: *@This()) void {
        _ = self;
    }
};

fn get_line(input: []const u8, at: usize) []const u8 {
    var line_start: usize = 0;
    var line_end: usize = 0;
    var current_pos: usize = 0;
    const cap = input.len;

    // search the start pos of the line
    while (current_pos < cap and current_pos < at) : (current_pos += 1) {
        if (input[current_pos] == '\n' and current_pos + 1 < cap) {
            line_start = current_pos + 1;
        }
    }

    // search the end pos of the line
    while (current_pos < cap) : (current_pos += 1) {
        // EOF is EOL
        if (current_pos + 1 == cap) {
            line_end = current_pos + 1;
            break;
        }
        if (input[current_pos] == '\n') {
            // dont count the newline as part of the... line
            line_end = current_pos;
            break;
        }
    }

    return input[line_start..line_end];
}

test {
    std.testing.refAllDecls(@This());
}

test "should get a single line" {
    const input = "print(hello)";
    const at = 4;
    const output = get_line(input, at);

    try std.testing.expectEqualStrings("print(hello)", output);
}

test "should get line from 2 lines (1)" {
    const input = "print(hello)\nprint(bye)";
    const at = 4;
    const output = get_line(input, at);

    try std.testing.expectEqualStrings("print(hello)", output);
}

test "should get line from 2 lines (2)" {
    const input = "print(hello)\nprint(bye)";
    const at = 15;
    const output = get_line(input, at);

    try std.testing.expectEqualStrings("print(bye)", output);
}

test "should get line from 2 lines (3)" {
    const input = "print(hello)\nprint(sure?)\nprint(bye!)";
    const at = 15;
    const output = get_line(input, at);

    try std.testing.expectEqualStrings("print(sure?)", output);
}

test "should gen error message" {
    // get_error_str
    const source = "print(ehh)";
    var err = ErrorData{
        .reason = "Invalid identifier",
        .start_position = 6,
        .end_position = 9,
    };
    const out = try err.get_error_str(source, std.testing.allocator);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        \\Error: Invalid identifier
        \\print(ehh)
    , out);
}
