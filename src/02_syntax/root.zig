const std = @import("std");
const lexic = @import("lexic");
const error_context = @import("context");

pub const context = @import("./context.zig");
const primary_expression = @import("./expression/primary_expression.zig");
const variable = @import("./variable.zig");
const types = @import("./types.zig");
const statement = @import("./statement.zig");
const m_pratt_expression = @import("./expression/pratt_expression.zig");
const m_primary_expression = @import("./expression/primary_expression.zig");

// export AST nodes to other modules
pub const Statement = statement.Statement;
pub const VariableBinding = variable.VariableBinding;
pub const Expression = primary_expression.PrimaryExpression;
pub const PrattExpression = m_pratt_expression.PrattExpression;
pub const PrimaryExpression = m_primary_expression.PrimaryExpression;

const Token = lexic.Token;
const TokenType = lexic.TokenType;
const ParseError = types.ParseError;
const TokenStream = types.TokenStream;

// FIXME: remove this, temp import to force testing
pub const test_import = @import("./expression/pratt_expression.zig");

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
        errdefer for (arrl.items) |*i| {
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
            {
                // get current token at current pos & print error
                // there MUST be a valid token in here, otherwise this loop shouldnt even be running
                const c_token = ctx.tokens.items[current_pos];
                var err = try ctx.err.create_and_append_error("No statement matched", c_token.start_pos, c_token.end_pos());

                const token_name = c_token.token_type.to_string();
                const error_name = try std.fmt.allocPrint(ctx.err.allocator, "This token `{s}` didnt match any construct", .{token_name});
                try err.add_label(ctx.err.create_error_label_alloc(
                    error_name,
                    c_token.start_pos,
                    c_token.end_pos(),
                ));
            }
            return error.Error;
        }

        target.* = .{
            .statements = arrl,
        };
    }

    pub fn deinit(self: *@This(), ctx: *const context.ParserContext) void {
        for (self.statements.items) |*stmt| {
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
    const input = "var my_variable = 322 var 644";
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
