const std = @import("std");
const lexic = @import("lexic");
const errors = @import("errors");
const context = @import("context");

const expression = @import("./expression.zig");
const variable = @import("./variable.zig");
const types = @import("./types.zig");
const statement = @import("./statement.zig");

const Token = lexic.Token;
const TokenType = lexic.TokenType;
const ParseError = types.ParseError;
const TokenStream = types.TokenStream;

pub const Module = struct {
    statements: std.ArrayList(statement.Statement),
    alloc: std.mem.Allocator,

    /// Parses a module.
    ///
    /// If this function fails an error will be returned, and additionally the out parameter
    /// `error_target` will be populated. If the error returned is OOM, nothing will be there.
    /// In that case, the caller is responsible for calling the error `deinit` method,
    /// which will clean it.
    pub fn init(
        target: *@This(),
        tokens: *const TokenStream,
        pos: usize,
        allocator: std.mem.Allocator,
        err_arrl: *std.ArrayList(errors.ErrorData),
    ) ParseError!void {
        var arrl = std.ArrayList(statement.Statement).init(allocator);
        errdefer arrl.deinit();
        errdefer for (arrl.items) |i| {
            i.deinit();
        };

        const input_len = tokens.items.len;
        var current_pos = pos;

        // parse many statements
        while (current_pos < input_len) {
            var stmt: statement.Statement = undefined;
            var current_error: errors.ErrorData = undefined;

            // TODO: handle other errors of vardef parsing
            const next_pos = stmt.init(tokens, current_pos, &current_error, allocator) catch |e| switch (e) {
                error.Error => {
                    // add the error to the list of errors,
                    // and exit for now because i havent implemented
                    // error recovery yet
                    try err_arrl.append(current_error);
                    return error.Error;
                },
                else => return e,
            };
            if (next_pos) |next_pos_actual| {
                current_pos = next_pos_actual;

                try arrl.append(stmt);
                continue;
            }

            // nothing matched, but there are tokens. this in an error
            var err: errors.ErrorData = undefined;
            try err.init(
                "No statement matched",
                current_pos,
                current_pos + 1,
                allocator,
            );
            try err_arrl.append(err);
            return error.Error;
        }

        target.* = .{
            .statements = arrl,
            .alloc = allocator,
        };
    }

    pub fn deinit(self: @This()) void {
        for (self.statements.items) |stmt| {
            stmt.deinit();
        }
        self.statements.deinit();
    }
};

test {
    std.testing.refAllDecls(@This());
}

test "should parse a single statement" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "var my_variable = 322";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, &ctx);
    defer tokens.deinit();

    var module: Module = undefined;
    _ = try module.init(&tokens, 0, std.testing.allocator, &error_list);

    defer module.deinit();
}

test "should clean memory if a statement parsing fails after one item has been inserted" {
    var ctx = context.CompilerContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "var my_variable = 322 unrelated()";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, &ctx);
    defer tokens.deinit();

    var module: Module = undefined;
    _ = module.init(&tokens, 0, std.testing.allocator, &error_list) catch {
        return;
    };
    defer module.deinit();
}
