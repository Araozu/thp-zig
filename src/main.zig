const std = @import("std");
const lexic = @import("lexic");
const syntax = @import("syntax");
const semantic = @import("semantic");
const codegen = @import("codegen");
const err_ctx = @import("context");
const parser_ctx = syntax.context;

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

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Values for semantic analysis that persist across REPL runs
    var global_scope = semantic.Scope.init(arena.allocator());
    defer global_scope.deinit();

    var symbol_table = semantic.SymbolTable{
        .scope = &global_scope,
    };

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
        var ctx = err_ctx.ErrorContext.init(alloc);
        defer ctx.deinit();

        //
        // Tokenize with an arena
        //
        const tokens = lexic.tokenize(line, arena.allocator(), &ctx) catch |e| switch (e) {
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
        var parser_context = parser_ctx.ParserContext{
            .allocator = arena.allocator(),
            .tokens = &tokens,
            .err = &ctx,
        };

        var ast: syntax.Module = undefined;
        ast.init(0, &parser_context) catch |e| switch (e) {
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

        semantic.semantic_analysis_unmanaged(&symbol_table, alloc, &ast, &ctx) catch |e| switch (e) {
            error.OutOfMemory => {
                try stdout.print("System ran out of memory!\n", .{});
                break;
            },
            else => {
                // Print all the errors
                for (ctx.errors.items) |*err_item| {
                    std.debug.print("ehhh???\n", .{});
                    const err_str = try err_item.get_error_str(line, "repl", alloc);
                    try stdout.print("\n{s}\n", .{err_str});
                    try bw.flush();
                    alloc.free(err_str);
                }
                continue;
            },
        };

        codegen.gen_php(arena.allocator(), &ast) catch |e| switch (e) {
            error.OutOfMemory => {
                try stdout.print("System ran out of memory!\n", .{});
                break;
            },
            else => {},
        };
    }

    try stdout.print("\n\nExecution finished. Bye c:\n", .{});
    try bw.flush();
}

inline fn trace_header() void {
    std.debug.print("  |TRACE> ", .{});
}
