const std = @import("std");

/// Compiler wide state about.
/// For now only stores errors generated
pub const ErrorContext = struct {
    allocator: std.mem.Allocator,
    errors: std.ArrayList(ErrorData),

    pub fn init(allocator: std.mem.Allocator) ErrorContext {
        return .{
            .allocator = allocator,
            .errors = std.ArrayList(ErrorData).init(allocator),
        };
    }

    /// Creates a new compiler error and appends it to the context's error list.
    ///
    /// This function creates an `ErrorData` instance and adds it to the context's error list.
    /// IMPORTANT: The returned pointer becomes invalid if the error list needs to reallocate,
    /// which happens when a new error is appended to the context.
    ///
    /// Example:
    /// ```zig
    /// const err = try ctx.create_and_append_error("Syntax error", 10, 15);
    /// // Safe to use err here
    /// try err.add_label(...);
    /// // After this point, err might become invalid if new errors are added
    /// ```
    pub fn create_and_append_error(
        self: *ErrorContext,
        reason: []const u8,
        start_position: usize,
        end_position: usize,
    ) !*ErrorData {
        const new_error = ErrorData{
            .reason = reason,
            .start_position = start_position,
            .end_position = end_position,
            .labels = std.ArrayList(ErrorLabel).init(self.allocator),
            .help = null,
        };

        // Append the error to the array list
        try self.errors.append(new_error);
        // Get a pointer to the newly appended error
        const ptr = &self.errors.items[self.errors.items.len - 1];
        return ptr;
    }

    /// Creates a new ErrorLabel with a static message.
    /// This error is meant to be added to a ErrorData,
    /// and will be cleaned automatically
    pub fn create_error_label(
        self: *ErrorContext,
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

    /// Creates a new ErrorLabel with a dynamic message.
    /// Resource cleanup is automatic.
    ///
    /// `message` **must** be allocated with the allocator
    /// of this context, because on cleanup this will be
    /// passed to `ctx.allocator.destroy(message)`.
    pub fn create_error_label_alloc(
        self: *ErrorContext,
        message: []u8,
        start: usize,
        end: usize,
    ) ErrorLabel {
        _ = self;
        return .{
            .message = .{ .dynamic = message },
            .start = start,
            .end = end,
        };
    }

    pub fn deinit(self: *ErrorContext) void {
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

    pub fn add_label(self: *ErrorData, label: ErrorLabel) !void {
        try self.labels.append(label);
    }

    /// Sets the help message of this error.
    pub fn set_help(self: *ErrorData, help: []const u8) void {
        self.help = help;
    }

    /// Generates an error string. `alloc` is used to create the string,
    /// the caller should call `free` on the returning slice.
    pub fn get_error_str(self: *ErrorData, source_code: []const u8, filename: []const u8, alloc: std.mem.Allocator) ![]u8 {
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

            // Build the error position indicator
            const column_number_len_str = try std.fmt.allocPrint(
                alloc,
                "{d}",
                .{label_line.line_number},
            );
            const column_number_len = column_number_len_str.len;
            alloc.free(column_number_len_str);

            // position up to where the error starts
            const error_start_len = column_number_len + 4 + label_line.column_number - 1;
            const error_len = label.end - label.start;

            // chars for the error
            const empty_space_before_indicator = try alloc.alloc(u8, error_start_len);
            defer alloc.free(empty_space_before_indicator);
            @memset(empty_space_before_indicator, ' ');

            // top error indicator: unicode box drawing characters in the range U+250x-U+257x (3 bytes)
            const error_indicator = try alloc.alloc(u8, error_len * 3);
            defer alloc.free(error_indicator);

            // the first char is always '╭', the rest are lines
            error_indicator[0] = '\xe2';
            error_indicator[1] = '\x95';
            error_indicator[2] = '\xad';

            // set bytes of the rest
            var i: usize = 1;
            while (i < error_len) : (i += 1) {
                // set bytes
                error_indicator[i * 3 + 0] = '\xe2';
                error_indicator[i * 3 + 1] = '\x94';
                error_indicator[i * 3 + 2] = '\x80';
            }

            // bottom error indicator: always ╰─
            const bottom_error_indicator = "╰─";

            const help_message: []u8 = msg: {
                if (self.help) |help_text| {
                    // this will be manually freed later
                    break :msg try std.fmt.allocPrint(alloc, "\n Help: {s}", .{help_text});
                } else {
                    break :msg "";
                }
            };
            defer if (help_message.len > 0) {
                alloc.free(help_message);
            };

            const label_error = try std.fmt.allocPrint(alloc,
                \\
                \\
                \\ {d} | {s}
                \\{s}{s}
                \\{s}{s} {s}
                \\{s}
            , .{
                label_line.line_number,
                label_line.line,
                empty_space_before_indicator,
                error_indicator,
                empty_space_before_indicator,
                bottom_error_indicator,
                switch (label.message) {
                    .static => label.message.static,
                    .dynamic => label.message.dynamic,
                },
                help_message,
            });
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

    /// Writes this error as a JSON to the writer
    pub fn write_json(self: ErrorData, alloc: std.mem.Allocator, writer: anytype) !void {
        // get this as JSON
        const json_str = try std.json.stringifyAlloc(alloc, .{
            .reason = self.reason,
            .help = self.help,
            .start_position = self.start_position,
            .end_position = self.end_position,
            .labels = self.labels.items,
        }, .{});
        defer alloc.free(json_str);

        // write the JSON to the writer
        try writer.writeAll(json_str);
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
        .help = null,
        .start_position = 6,
        .end_position = 9,
        .labels = std.ArrayList(ErrorLabel).init(std.testing.allocator),
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
        .help = null,
        .start_position = 6,
        .end_position = 9,
        .labels = std.ArrayList(ErrorLabel).init(std.testing.allocator),
    };
    defer err.deinit(std.testing.allocator);

    const label = ErrorLabel{
        .message = .{ .static = "This identifier was not found" },
        .start = 6,
        .end = 9,
    };
    try err.add_label(label);

    const out = try err.get_error_str(source, "repl", std.testing.allocator);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        \\Error: Invalid identifier
        \\[repl:1:7]
        \\
        \\ 1 | print(ehh)
        \\           ╭──
        \\           ╰─ This identifier was not found
        \\
    , out);
}

test "should gen error message with label and help" {
    const source = "print(ehh)";
    var err = ErrorData{
        .reason = "Invalid identifier",
        .help = null,
        .start_position = 6,
        .end_position = 9,
        .labels = std.ArrayList(ErrorLabel).init(std.testing.allocator),
    };
    defer err.deinit(std.testing.allocator);

    const label = ErrorLabel{
        .message = .{ .static = "This identifier was not found" },
        .start = 6,
        .end = 9,
    };
    try err.add_label(label);
    err.set_help("Define the identifier");

    const out = try err.get_error_str(source, "repl", std.testing.allocator);
    defer std.testing.allocator.free(out);

    try std.testing.expectEqualStrings(
        \\Error: Invalid identifier
        \\[repl:1:7]
        \\
        \\ 1 | print(ehh)
        \\           ╭──
        \\           ╰─ This identifier was not found
        \\
        \\ Help: Define the identifier
    , out);
}

test "should serialize a minimal error" {
    var err = ErrorData{
        .reason = "Invalid identifier",
        .help = null,
        .start_position = 6,
        .end_position = 9,
        .labels = std.ArrayList(ErrorLabel).init(std.testing.allocator),
    };
    defer err.deinit(std.testing.allocator);
    var out_writer = std.ArrayList(u8).init(std.testing.allocator);
    defer out_writer.deinit();

    try err.write_json(std.testing.allocator, out_writer.writer());

    const expected =
        \\{"reason":"Invalid identifier","help":null,"start_position":6,"end_position":9,"labels":[]}
    ;
    try std.testing.expectEqualStrings(expected, out_writer.items);
}

test "should serialize a complex error" {
    var err = ErrorData{
        .reason = "Invalid \"hello\"",
        .help = "Try to do better",
        .start_position = 0,
        .end_position = 1,
        .labels = std.ArrayList(ErrorLabel).init(std.testing.allocator),
    };
    defer err.deinit(std.testing.allocator);

    try err.add_label(.{
        .message = .{ .static = "This one" },
        .start = 0,
        .end = 32,
    });
    try err.add_label(.{
        .message = .{ .static = "And this other" },
        .start = 32,
        .end = 64,
    });

    var out_writer = std.ArrayList(u8).init(std.testing.allocator);
    defer out_writer.deinit();

    try err.write_json(std.testing.allocator, out_writer.writer());

    const expected =
        \\{"reason":"Invalid \"hello\"","help":"Try to do better","start_position":0,"end_position":1,"labels":[{"message":{"static":"This one"},"start":0,"end":32},{"message":{"static":"And this other"},"start":32,"end":64}]}
    ;
    try std.testing.expectEqualStrings(expected, out_writer.items);
}

// TODO: add more tests:
// - when the error has len=1
// - when the error has len=0
// - when the error spans across 2 lines
