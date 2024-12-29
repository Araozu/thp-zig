const std = @import("std");
const lexic = @import("lexic");
const syntax = @import("syntax");
const errors = @import("errors");

const tracing = @import("config").tracing;

const thp_version: []const u8 = "0.0.1";

pub fn main() !void {
    try repl();
}

fn repl() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    if (tracing) {
        try stdout.print("\n|\n| DEBUG MODE\n|\n\n", .{});
        try bw.flush();
    }

    try stdout.print("The THP REPL, v{s}\n", .{thp_version});
    try stdout.print("Enter expressions to evaluate. Enter CTRL-D to exit.\n", .{});
    try bw.flush();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const stdin = std.io.getStdIn().reader();

    while (true) {
        //
        // Print prompt
        //
        try stdout.print("\nthp => ", .{});
        try bw.flush();

        //
        // Read stdin, break if EOF (C-d)
        //
        const bare_line = stdin.readUntilDelimiterAlloc(std.heap.page_allocator, '\n', 8192) catch |e| switch (e) {
            error.EndOfStream => {
                break;
            },
            else => return e,
        };
        defer std.heap.page_allocator.free(bare_line);
        const line = std.mem.trim(u8, bare_line, "\r");

        //
        // Tokenize
        //
        var error_array = std.ArrayList(errors.ErrorData).init(alloc);
        defer error_array.deinit();

        const tokens = lexic.tokenize(line, alloc, &error_array) catch |e| switch (e) {
            error.OutOfMemory => {
                try stdout.print("FATAL ERROR: System Out of Memory!", .{});
                try bw.flush();
                return e;
            },
            else => return e,
        };
        defer tokens.deinit();

        // Trace tokens
        if (tracing) {
            for (tokens.items) |token| {
                trace_header();
                std.debug.print(
                    "token: `{s}`, type: `{s}`, start: `{d}` \n",
                    .{ token.value, @tagName(token.token_type), token.start_pos },
                );
            }
        }

        // Print errors
        for (error_array.items) |e| {
            var err = e;
            const err_str = try err.get_error_str(line, "repl", alloc);
            try stdout.print("\n{s}\n", .{err_str});
            try bw.flush();
            alloc.free(err_str);
        }

        // next repl line
    }

    // var module_ast: syntax.Module = undefined;
    // const parsing_error = try alloc.create(errors.ErrorData);
    // defer parsing_error.deinit();
    // defer alloc.destroy(parsing_error);
    //
    // try module_ast.init(&tokens, 0, alloc, parsing_error);

    try stdout.print("\n\nExecution finished. Bye c:\n", .{});
    try bw.flush();
}

inline fn trace_header() void {
    std.debug.print("  |TRACE> ", .{});
}
