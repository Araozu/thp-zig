const std = @import("std");
const lexic = @import("lexic");
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
        ctx: *context.ErrorContext,
    ) ParseError!void {
        var arrl = std.ArrayList(statement.Statement).init(ctx.allocator);
        errdefer arrl.deinit();
        errdefer for (arrl.items) |i| {
            i.deinit(ctx);
        };

        const input_len = tokens.items.len;
        var current_pos = pos;

        // parse many statements
        while (current_pos < input_len) {
            var stmt: statement.Statement = undefined;

            const next_pos = try stmt.init(tokens, current_pos, ctx);
            if (next_pos) |next_pos_actual| {
                current_pos = next_pos_actual;

                try arrl.append(stmt);
                continue;
            }

            // nothing matched, but there are tokens. this in an error
            _ = try ctx.create_and_append_error("No statement matched", current_pos, current_pos + 1);
            return error.Error;
        }

        target.* = .{
            .statements = arrl,
        };
    }

    pub fn deinit(self: @This(), ctx: *context.ErrorContext) void {
        for (self.statements.items) |stmt| {
            stmt.deinit(ctx);
        }
        self.statements.deinit();
    }
};

test {
    std.testing.refAllDecls(@This());
}

test "should parse a single statement" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "var my_variable = 322";
    const tokens = try lexic.tokenize(input, std.testing.allocator, &ctx);
    defer tokens.deinit();

    var module: Module = undefined;
    _ = try module.init(&tokens, 0, &ctx);
    defer module.deinit(&ctx);
}

test "should clean memory if a statement parsing fails after one item has been inserted" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "var my_variable = 322 unrelated()";
    const tokens = try lexic.tokenize(input, std.testing.allocator, &ctx);
    defer tokens.deinit();

    var module: Module = undefined;
    _ = module.init(&tokens, 0, &ctx) catch {
        return;
    };
    defer module.deinit(&ctx);
}
