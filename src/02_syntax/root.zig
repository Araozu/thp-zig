const std = @import("std");
const lexic = @import("lexic");
const errors = @import("errors");

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
        error_target: *errors.ErrorData,
    ) ParseError!void {
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

            const next_pos = stmt.init(tokens, current_pos, allocator) catch |e| {
                switch (e) {
                    error.Unmatched => {
                        // create the error value
                        error_target.init(
                            "No statement found",
                            current_pos,
                            current_pos + 1,
                        );
                        return error.Unmatched;
                    },
                    else => return e,
                }
            };
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
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
    defer tokens.deinit();

    const error_target = try std.testing.allocator.create(errors.ErrorData);
    defer std.testing.allocator.destroy(error_target);

    var module: Module = undefined;
    _ = try module.init(&tokens, 0, std.testing.allocator, error_target);

    defer module.deinit();
}

test "should clean memory if a statement parsing fails after one item has been inserted" {
    const input = "var my_variable = 322 unrelated()";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const tokens = try lexic.tokenize(input, std.testing.allocator, &error_list);
    defer tokens.deinit();

    const error_target = try std.testing.allocator.create(errors.ErrorData);
    defer std.testing.allocator.destroy(error_target);

    var module: Module = undefined;
    _ = module.init(&tokens, 0, std.testing.allocator, error_target) catch {
        return;
    };
    defer module.deinit();
}
