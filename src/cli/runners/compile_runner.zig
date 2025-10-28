const std = @import("std");

const lexic = @import("lexic");
const syntax = @import("syntax");
const semantic = @import("semantic");
const codegen = @import("codegen");
const err_ctx = @import("context");
const parser_ctx = syntax.context;

const config = @import("config");
const tracing = config.tracing;

const CompileOptions = @import("../compile_command.zig").CompileOptions;

/// Runs the compile command.
pub fn run(self: *const CompileOptions) !void {
    // Read file

    var filebuffer: [4096]u8 = undefined;
    const absolute_path = try std.fs.realpath(self.filename, &filebuffer);

    const source_file = try std.fs.createFileAbsolute(absolute_path, std.fs.File.CreateFlags{
        .read = true,
        .truncate = false,
    });

    // 20MB max buffer
    var file_buffer: [1024 * 1024 * 20]u8 = undefined;
    const read_bytes = try source_file.read(&file_buffer);
    const file_bytes = file_buffer[0..read_bytes];

    // ==========================================
    //   Setup
    // ==========================================
    // FIXME: handle writing to disk
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    if (tracing) {
        try stdout.print("\n|\n| DEBUG MODE\n|\n\n", .{});
        try stdout.flush();
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Setup compiler context
    var ctx = err_ctx.ErrorContext.init(alloc);
    defer ctx.deinit();

    // ==========================================
    //   Lex
    // ==========================================

    var tokens = lexic.tokenize(file_bytes, alloc, &ctx) catch |e| switch (e) {
        error.OutOfMemory => {
            try stdout.print("FATAL ERROR: System Out of Memory!", .{});
            try stdout.flush();
            return e;
        },
        else => return e,
    };
    defer tokens.deinit(alloc);

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

    // Display errors
    if (ctx.errors.items.len > 0) {
        for (ctx.errors.items) |*err| {
            const err_str = try err.get_error_str(file_bytes, "<file>", alloc);
            try stdout.print("\n{s}\n", .{err_str});
            try stdout.flush();
            alloc.free(err_str);
        }

        // FIXME: return with error
        return;
    }

    // ==========================================
    //   Parse
    // ==========================================

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
                const err_str = try err_item.get_error_str(file_bytes, "<file>", alloc);
                try stdout.print("\n{s}\n", .{err_str});
                try stdout.flush();
                alloc.free(err_str);
            }
            return;
        },
        else => return e,
    };
    defer ast.deinit(&parser_context);

    // ==========================================
    //   Analyze
    // ==========================================

    var symbol_table: semantic.SymbolTable = undefined;
    try symbol_table.init(arena.allocator());
    defer symbol_table.deinit();

    semantic.semantic_analysis_unmanaged(&symbol_table, alloc, &ast, &ctx) catch |e| switch (e) {
        error.OutOfMemory => {
            try stdout.print("System ran out of memory!\n", .{});
            return;
        },
        else => {
            // Print all the errors
            for (ctx.errors.items) |*err_item| {
                const err_str = try err_item.get_error_str(file_bytes, "<file>", alloc);
                try stdout.print("\n{s}\n", .{err_str});
                try stdout.flush();
                alloc.free(err_str);
            }
            return;
        },
    };

    // ==========================================
    //   Emit
    // ==========================================

    var generator: codegen.ByteCodeGenerator = undefined;
    generator.init(&ast, arena.allocator());

    var chunk = try generator.emit();
    defer chunk.deinit();

    // ==========================================
    //   Out
    // ==========================================

    for (chunk.code.items) |byte| {
        std.debug.print("{X:0>2} ", .{byte});
    }
    std.debug.print("\n", .{});
    for (chunk.constants.items) |value| {
        std.debug.print("{d} ", .{value});
    }
    std.debug.print("\n", .{});
}

inline fn trace_header() void {
    std.debug.print("  |TRACE> ", .{});
}
