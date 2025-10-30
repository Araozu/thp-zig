const std = @import("std");
const config = @import("config");
const context = @import("context");
const lexic = @import("lexic");
const syntax = @import("syntax");
const semantic = @import("semantic");

const ParserContext = syntax.context.ParserContext;

const CompileOptions = @import("../compile_command.zig").CompileOptions;

/// Runs the `lex` command
pub fn run() !void {
    if (!config.json) {
        std.debug.print("JSON output not enabled, compile thp with the `-Djson` flag\n", .{});
    }

    // gpa for error context and buffer reading
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Setup buffered stdout once
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    // Read all stdin
    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    // 16MB, why would anyone ever have source code bigger than that??
    const stdin_buffer = try allocator.alloc(u8, 16 * 1024 * 1024);
    defer allocator.free(stdin_buffer);

    var stdin_reader = std.fs.File.stdin().reader(stdin_buffer);
    _ = try stdin_reader.interface.streamRemaining(&aw.writer);

    // Setup compiler context
    var ctx = context.ErrorContext.init(allocator);
    defer ctx.deinit();

    // Tokenize
    var tokens = try lexic.tokenize(aw.written(), allocator, &ctx);
    defer tokens.deinit(allocator);
    const tokenize_error = ctx.errors.items.len > 0;

    // syntax analysis
    var parser_context = ParserContext{
        .allocator = arena.allocator(),
        .tokens = &tokens,
        .err = &ctx,
    };

    var ast: syntax.Module = undefined;
    var parser_error = false;
    var global_scope = semantic.Scope.init(arena.allocator());
    defer global_scope.deinit();

    var symbol_table: semantic.SymbolTable = undefined;
    try symbol_table.init(arena.allocator());
    defer symbol_table.deinit();

    if (!tokenize_error) {
        ast.init(0, &parser_context) catch |e| switch (e) {
            error.Error => {
                parser_error = true;
            },
            else => return e,
        };
        defer ast.deinit(&parser_context);

        if (!parser_error) {
            // semantic analysis
            semantic.semantic_analysis_unmanaged(&symbol_table, allocator, &ast, &ctx) catch |e| switch (e) {
                error.OutOfMemory => {
                    try stdout.print("System ran out of memory!\n", .{});
                },
                else => {},
            };
        }
    }

    // Write JSON directly to stdout
    try stdout.writeAll("{\"errors\":[");
    for (ctx.errors.items, 0..) |err, idx| {
        try err.write_json(allocator, stdout);
        if (idx < ctx.errors.items.len - 1) try stdout.writeAll(",");
    }
    try stdout.writeAll("],\"tokens\":");
    try std.json.Stringify.value(tokens.items, .{}, stdout);
    try stdout.writeAll(",\"references\":");
    try symbol_table.scope.symbols_json(stdout);
    try stdout.writeAll("}");
    try stdout.flush();
}
