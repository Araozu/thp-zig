const std = @import("std");
const lexic = @import("lexic");
const syntax = @import("syntax");
const context = @import("context");

const cli = @import("cli.zig");

const config = @import("config");
const tracing = config.tracing;
const json = config.json;

const thp_version: []const u8 = "0.0.1";

pub fn main() !void {
    try repl();
}

fn repl() !void {
    // first check to see if we are serializing tokens
    var args = std.process.args();
    defer args.deinit();

    // If compiling for JSON serialization, enable the binary `lex` command

    // ignore executable
    _ = args.next();
    if (args.next()) |arg| {
        if (json) {
            if (std.mem.eql(u8, "lex", arg)) {
                try cli.tokenize_to_json();
                return;
            }
        }
    }

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

        // Setup compiler context
        var ctx = context.CompilerContext.init(alloc);
        defer ctx.deinit();

        //
        // Tokenize
        //
        const tokens = lexic.tokenize(line, &ctx) catch |e| switch (e) {
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

        // Print errors and continue, if any
        if (ctx.errors.items.len > 0) {
            for (ctx.errors.items) |*err| {
                const err_str = try err.get_error_str(line, "repl", alloc);
                try stdout.print("\n{s}\n", .{err_str});
                try bw.flush();
                alloc.free(err_str);
            }
            continue;
        }

        //
        // Syntax analysis
        //
        var ast: syntax.Module = undefined;
        ast.init(&tokens, 0, &ctx) catch |e| switch (e) {
            error.Error => {
                // Print all the errors
                for (ctx.errors.items) |*err_item| {
                    const err_str = try err_item.get_error_str(line, "repl", alloc);
                    try stdout.print("\n{s}\n", .{err_str});
                    try bw.flush();
                    alloc.free(err_str);
                }
                continue;
            },
            else => return e,
        };

        // next repl line
        std.debug.print("Parsing successful\n", .{});
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
