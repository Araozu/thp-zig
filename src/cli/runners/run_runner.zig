const std = @import("std");
const vm = @import("vm");

const lexic = @import("lexic");
const syntax = @import("syntax");
const semantic = @import("semantic");
const codegen = @import("codegen");
const err_ctx = @import("context");
const parser_ctx = syntax.context;

const config = @import("config");
const tracing = config.tracing;

const RunOptions = @import("../run_command.zig").RunOptions;

var stderr_buffer: [128]u8 = undefined;
var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
var stderr = &stderr_writer.interface;

/// Runs the run command - compiles and executes code in the VM.
pub fn run(self: *const RunOptions) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Read file
    var file_path_buffer: [4096]u8 = undefined;
    const absolute_path = std.fs.realpath(self.filename, &file_path_buffer) catch |e| switch (e) {
        error.FileNotFound => {
            try stderr.print("File `{s}` not found.\n", .{self.filename});
            try stderr.flush();
            std.process.exit(1);
        },
        else => return e,
    };

    const source_file = try std.fs.createFileAbsolute(absolute_path, std.fs.File.CreateFlags{
        .read = true,
        .truncate = false,
    });
    defer source_file.close();

    // Source files must be 1MB max
    var file_buffer = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(file_buffer);

    const read_bytes = try source_file.read(file_buffer);
    const file_bytes = file_buffer[0..read_bytes];

    // ==========================================
    //   Setup
    // ==========================================

    if (tracing) {
        try stderr.print("\n|\n| DEBUG MODE\n|\n\n", .{});
        try stderr.flush();
    }

    // Setup compiler context
    var ctx = err_ctx.ErrorContext.init(allocator);
    defer ctx.deinit();

    // ==========================================
    //   Lex
    // ==========================================

    var tokens = lexic.tokenize(file_bytes, allocator, &ctx) catch |e| switch (e) {
        error.OutOfMemory => {
            try stderr.print("FATAL ERROR: System Out of Memory!", .{});
            try stderr.flush();
            return e;
        },
        else => return e,
    };
    defer tokens.deinit(allocator);

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
            const err_str = try err.get_error_str(file_bytes, "<file>", allocator);
            try stderr.print("\n{s}\n", .{err_str});
            try stderr.flush();
            allocator.free(err_str);
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
                const err_str = try err_item.get_error_str(file_bytes, "<file>", allocator);
                try stderr.print("\n{s}\n", .{err_str});
                try stderr.flush();
                allocator.free(err_str);
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

    var semantic_ctx = semantic.semantic_analysis_unmanaged(&symbol_table, allocator, &ast, &ctx) catch |e| switch (e) {
        error.OutOfMemory => {
            try stderr.print("System ran out of memory!\n", .{});
            try stderr.flush();
            return;
        },
        else => {
            // Print all the errors
            for (ctx.errors.items) |*err_item| {
                const err_str = try err_item.get_error_str(file_bytes, "<file>", allocator);
                try stderr.print("\n{s}\n", .{err_str});
                try stderr.flush();
                allocator.free(err_str);
            }
            return;
        },
    };
    defer semantic_ctx.deinit();

    // ==========================================
    //
    //   Emit
    //
    // ==========================================

    var chunk: vm.Chunk = undefined;
    defer chunk.deinit();
    chunk.init(allocator);

    var codegen_ctx = codegen.CodegenContext{
        .allocator = allocator,
        .semantic_ctx = &semantic_ctx,
        .chunk = &chunk,
    };

    try codegen.emit_ast(&codegen_ctx, &ast);

    // ==========================================
    //   Execute in VM
    // ==========================================

    var stdout = std.fs.File.stdout();
    var stdout_writer = stdout.writer("" ** 16);

    var virtual_machine: vm.VM = undefined;
    virtual_machine.init(&chunk, &stdout_writer.interface);
    defer virtual_machine.deinit();

    const result = virtual_machine.run();
    if (result != .INTERPRET_OK) {
        std.process.exit(1);
    }
}

inline fn trace_header() void {
    std.debug.print("  |TRACE> ", .{});
}
