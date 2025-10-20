const std = @import("std");
const lexic = @import("lexic");
pub const context = @import("./context.zig");
const error_context = @import("context");

const call_expression = @import("./expression/call_expression.zig");
const expression = @import("./expression.zig");
const variable = @import("./variable.zig");
const types = @import("./types.zig");
const statement = @import("./statement.zig");

// export AST nodes to other modules
pub const Statement = statement.Statement;
pub const VariableBinding = variable.VariableBinding;
pub const Expression = expression.Expression;
pub const CallExpression = call_expression.CallExpression;

const Token = lexic.Token;
const TokenType = lexic.TokenType;
const ParseError = types.ParseError;
const TokenStream = types.TokenStream;

/// A module in the AST.
pub const Module = struct {
    statements: std.ArrayListUnmanaged(statement.Statement),

    /// Parses a module.
    ///
    /// If this function fails an error will be returned, and additionally the out parameter
    /// `error_target` will be populated. If the error returned is OOM, nothing will be there.
    /// In that case, the caller is responsible for calling the error `deinit` method,
    /// which will clean it.
    pub fn init(
        target: *@This(),
        pos: usize,
        ctx: *const context.ParserContext,
    ) ParseError!void {
        var arrl = std.ArrayListUnmanaged(statement.Statement).empty;
        errdefer arrl.deinit(ctx.allocator);
        errdefer for (arrl.items) |i| {
            i.deinit(ctx);
        };

        const input_len = ctx.tokens.items.len;
        var current_pos = pos;

        // parse many statements
        while (current_pos < input_len) {
            var stmt: statement.Statement = undefined;

            if (ctx.tokens.items[current_pos].token_type == TokenType.Newline or ctx.tokens.items[current_pos].token_type == TokenType.Comment) {
                current_pos += 1;
                continue;
            }

            const next_pos = try stmt.init(current_pos, ctx);
            if (next_pos) |next_pos_actual| {
                current_pos = next_pos_actual;

                try arrl.append(ctx.allocator, stmt);
                continue;
            }

            // nothing matched, but there are tokens. this in an error
            _ = try ctx.err.create_and_append_error("No statement matched", current_pos, current_pos + 1);
            return error.Error;
        }

        target.* = .{
            .statements = arrl,
        };
    }

    pub fn deinit(self: *@This(), ctx: *const context.ParserContext) void {
        for (self.statements.items) |stmt| {
            stmt.deinit(ctx);
        }
        self.statements.deinit(ctx.allocator);
    }
};

test {
    std.testing.refAllDecls(@This());
}

test "should parse a single statement" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var my_variable = 322";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var module: Module = undefined;
    _ = try module.init(0, &parser_context);
    defer module.deinit(&parser_context);
}

test "should clean memory if a statement parsing fails after one item has been inserted" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "var my_variable = 322 unrelated()";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);

    const parser_context = context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &tokens,
        .err = &err_ctx,
    };
    var module: Module = undefined;
    _ = module.init(0, &parser_context) catch {
        return;
    };
    defer module.deinit(&parser_context);
}
