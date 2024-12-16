const std = @import("std");
const lexic = @import("lexic");
const expression = @import("./expression.zig");
const variable = @import("./variable.zig");
const types = @import("./types.zig");
const statement = @import("./statement.zig");

const Token = lexic.Token;
const TokenType = lexic.TokenType;
const ParseError = types.ParseError;
const TokenStream = types.TokenStream;

pub const Module = struct {
    statements: std.ArrayList(*statement.Statement),
    alloc: std.mem.Allocator,

    pub fn init(target: *@This(), tokens: *const TokenStream, pos: usize, allocator: std.mem.Allocator) ParseError!void {
        var arrl = std.ArrayList(*statement.Statement).init(allocator);
        errdefer arrl.deinit();
        errdefer for (arrl.items) |i| {
            i.deinit();
            allocator.destroy(i);
        };

        const input_len = tokens.items.len;
        var current_pos = pos;

        // parse many statements
        while (current_pos < input_len) {
            var stmt = try allocator.create(statement.Statement);
            errdefer allocator.destroy(stmt);

            const next_pos = try stmt.init(tokens, current_pos, allocator);
            current_pos = next_pos;

            try arrl.append(stmt);
        }

        target.* = .{
            .statements = arrl,
            .alloc = allocator,
        };
    }

    pub fn deinit(self: @This()) void {
        for (self.statements.items) |stmt| {
            stmt.deinit();
            self.alloc.destroy(stmt);
        }
        self.statements.deinit();
    }
};

test {
    std.testing.refAllDecls(@This());
}

test "should parse a single statement" {
    const input = "var my_variable = 322";
    const tokens = try lexic.tokenize(input, std.testing.allocator);
    defer tokens.deinit();

    var module: Module = undefined;
    _ = try module.init(&tokens, 0, std.testing.allocator);

    defer module.deinit();
}

test "should clean memory if a statement parsing fails after one item has been inserted" {
    const input = "var my_variable = 322 unrelated()";
    const tokens = try lexic.tokenize(input, std.testing.allocator);
    defer tokens.deinit();

    var module: Module = undefined;
    _ = module.init(&tokens, 0, std.testing.allocator) catch {
        return;
    };
    defer module.deinit();
}
