const std = @import("std");
const lexic = @import("lexic");
const syntax = @import("syntax");
const semantic = @import("semantic");
const ParserContext = syntax.context.ParserContext;
const context = @import("context");

pub fn tokenize_to_json() !void {
    // gpa for error context and buffer reading
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Setup buffered stdout once
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // Read all stdin
    var stdin_buf = std.ArrayList(u8).init(alloc);
    defer stdin_buf.deinit();
    // 16MB, why would anyone ever have source code bigger than that??
    const max_file_size = 16 * 1024 * 1024;
    try std.io.getStdIn().reader().readAllArrayList(&stdin_buf, max_file_size);

    // Setup compiler context
    var ctx = context.ErrorContext.init(alloc);
    defer ctx.deinit();

    // Tokenize
    // arena allocator for tokens
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const tokens = try lexic.tokenize(stdin_buf.items, arena.allocator(), &ctx);
    defer tokens.deinit();
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
    var symbol_table = semantic.SymbolTable{
        .scope = &global_scope,
    };

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
            semantic.semantic_analysis_unmanaged(&symbol_table, alloc, &ast, &ctx) catch |e| switch (e) {
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
        try err.write_json(alloc, stdout);
        if (idx < ctx.errors.items.len - 1) try stdout.writeAll(",");
    }
    try stdout.writeAll("],\"tokens\":");
    try std.json.stringify(tokens.items, .{}, stdout);
    try stdout.writeAll(",\"references\":");
    try symbol_table.scope.symbols_json(stdout);
    try stdout.writeAll("}");
    try bw.flush();
}
