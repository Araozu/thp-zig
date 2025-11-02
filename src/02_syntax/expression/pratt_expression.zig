const std = @import("std");
const context = @import("../context.zig");

const m_primary_expression = @import("primary_expression.zig");
const PrimaryExpression = m_primary_expression.PrimaryExpression;

pub const PrattExpression = union(enum) {
    primary: *PrimaryExpression,

    const Self = @This();

    pub fn init(
        self: *Self,
        pos: usize,
        ctx: *const context.ParserContext,
    ) !?usize {
        if (ctx.oob(pos)) return null;

        var next_pos = pos;

        // Parse a prefix (primary expression or unary)
        next_pos = try parse_prefix(self, next_pos, ctx) orelse return null;

        return next_pos;
    }

    fn parse_prefix(
        self: *Self,
        pos: usize,
        ctx: *const context.ParserContext,
    ) !?usize {
        if (ctx.oob(pos)) return null;
        var next_pos = pos;

        // TODO: parse unary operator (grammar only allows for `-` and `!`)

        // Try parsing primary expression
        var parsed_primary = try ctx.allocator.create(PrimaryExpression);
        errdefer ctx.allocator.destroy(parsed_primary);

        next_pos = try parsed_primary.init(next_pos, ctx) orelse {
            ctx.allocator.destroy(parsed_primary);
            return null;
        };
        self.* = .{
            .primary = parsed_primary,
        };
        return next_pos;
    }

    pub fn deinit(
        self: *Self,
        ctx: *const context.ParserContext,
    ) void {
        switch (self.*) {
            .primary => |p| {
                p.deinit(ctx);
                ctx.allocator.destroy(p);
            },
        }
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const error_context = @import("context");
const lexic = @import("lexic");

const TokenType = lexic.TokenType;

test "should parse a primary expression" {
    var err_ctx = error_context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();
    const input = "322";
    var tokens = try lexic.tokenize(input, std.testing.allocator, &err_ctx);
    defer tokens.deinit(std.testing.allocator);
    const parser_context = context.ParserContext{ .allocator = std.testing.allocator, .tokens = &tokens, .err = &err_ctx };

    var expr: PrattExpression = undefined;
    const next_pos = try expr.init(0, &parser_context) orelse {
        try expect(false);
        return;
    };
    defer expr.deinit(&parser_context);
    try expectEqual(1, next_pos);
}
