const std = @import("std");

pub const ErrorLabel = struct {
    message: []const u8,
    start: usize,
    end: usize,
};

/// Holds information about errors generated during the compilation,
/// and pretty prints them.
pub const ErrorData = struct {
    reason: []const u8,
    start_position: usize,
    end_position: usize,
    labels: std.ArrayList(ErrorLabel),
    alloc: std.mem.Allocator,

    pub fn init(
        target: *@This(),
        reason: []const u8,
        start_position: usize,
        end_position: usize,
        alloc: std.mem.Allocator,
    ) !void {
        target.* = .{
            .reason = reason,
            .start_position = start_position,
            .end_position = end_position,
            .labels = std.ArrayList(ErrorLabel).init(alloc),
            .alloc = alloc,
        };
    }

    pub fn add_label(self: *@This(), message: []const u8, start: usize, end: usize) !void {
        try self.labels.append(.{
            .message = message,
            .start = start,
            .end = end,
        });
    }

    /// Generates an error string. `alloc` is used to create the string,
    /// the caller should call `free` on the returning slice.
    pub fn get_error_str(self: *@This(), source_code: []const u8, filename: []const u8, alloc: std.mem.Allocator) ![]u8 {
        const faulty_line = get_line(source_code, self.start_position);

        var error_message = try std.fmt.allocPrint(alloc,
            \\Error: {s}
            \\[{s}:{d}:{d}]
        , .{
            self.reason,
            filename,
            faulty_line.line_number,
            faulty_line.column_number,
        });
        errdefer alloc.free(error_message);

        // generate errors for each label, and concat
        for (self.labels.items) |label| {
            const label_line = get_line(source_code, label.start);

            const label_error = try std.fmt.allocPrint(alloc,
                \\
                \\
                \\ {d} | {s}
                \\
            , .{ label_line.line_number, label_line.line });
            errdefer alloc.free(label_error);

            // append the previous bytes to the current ones,
            // in a temp variable
            const new_bytes = try std.mem.concat(alloc, u8, &[_][]const u8{ error_message, label_error });

            // free the previous bytes
            alloc.free(label_error);
            alloc.free(error_message);

            // reference the new bytes
            error_message = new_bytes;

            // continue
        }

        return error_message;
    }

    // TODO:
    // - transform absolute position into line:column
    // - Get previous, current and next line
    // - Display message

    pub fn deinit(self: *@This()) void {
        self.labels.deinit();
    }
};

const LineInfo = struct {
    line: []const u8,
    /// 1 based
    line_number: usize,
    /// 1 based
    column_number: usize,
};

fn get_line(input: []const u8, at: usize) LineInfo {
    var line_number: usize = 1;
    var line_start: usize = 0;
    var line_end: usize = 0;
    var current_pos: usize = 0;
    const cap = input.len;

    // search the start pos of the line
    while (current_pos < cap and current_pos < at) : (current_pos += 1) {
        if (input[current_pos] == '\n' and current_pos + 1 < cap) {
            line_start = current_pos + 1;
            line_number += 1;
        }
    }

    // compute the column number
    const column_number: usize = current_pos - line_start + 1;

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

    return .{
        .line = input[line_start..line_end],
        .line_number = line_number,
        .column_number = column_number,
    };
}

test {
    std.testing.refAllDecls(@This());
}

test "should get a single line" {
    const input = "print(hello)";
    const at = 4;
    const output = get_line(input, at);

    try std.testing.expectEqualStrings("print(hello)", output.line);
    try std.testing.expectEqual(1, output.line_number);
    try std.testing.expectEqual(5, output.column_number);
}

test "should get line from 2 lines (1)" {
    const input = "print(hello)\nprint(bye)";
    const at = 4;
    const output = get_line(input, at);

    try std.testing.expectEqualStrings("print(hello)", output.line);
    try std.testing.expectEqual(1, output.line_number);
    try std.testing.expectEqual(5, output.column_number);
}

test "should get line from 2 lines (2)" {
    const input = "print(hello)\nprint(bye)";
    const at = 15;
    const output = get_line(input, at);

    try std.testing.expectEqualStrings("print(bye)", output.line);
    try std.testing.expectEqual(2, output.line_number);
    try std.testing.expectEqual(3, output.column_number);
}

test "should get line from 2 lines (3)" {
    const input = "print(hello)\nprint(sure?)\nprint(bye!)";
    const at = 15;
    const output = get_line(input, at);

    try std.testing.expectEqualStrings("print(sure?)", output.line);
    try std.testing.expectEqual(2, output.line_number);
    try std.testing.expectEqual(3, output.column_number);
}

test "should gen error message" {
    const source = "print(ehh)";
    var err = ErrorData{
        .reason = "Invalid identifier",
        .start_position = 6,
        .end_position = 9,
        .labels = std.ArrayList(ErrorLabel).init(std.testing.allocator),
        .alloc = std.testing.allocator,
    };
    const out = try err.get_error_str(source, "repl", std.testing.allocator);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        \\Error: Invalid identifier
        \\[repl:1:7]
    , out);
}

test "should gen error message with label (1)" {
    const source = "print(ehh)";
    var err = ErrorData{
        .reason = "Invalid identifier",
        .start_position = 6,
        .end_position = 9,
        .labels = std.ArrayList(ErrorLabel).init(std.testing.allocator),
        .alloc = std.testing.allocator,
    };
    defer err.deinit();

    try err.add_label("This identifier was not found", 6, 9);

    const out = try err.get_error_str(source, "repl", std.testing.allocator);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        \\Error: Invalid identifier
        \\[repl:1:7]
        \\
        \\ 1 | print(ehh)
        \\
    , out);
}
