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

        const input_len = tokens.items.len;
        var current_pos = pos;

        // parse many statements
        while (current_pos < input_len) {
            std.debug.print("running on pos {d} \n", .{current_pos});

            // FIXME: if a statement was added to the array list,
            // and then one of these fails,
            // will all previous statements leak memory?
            var stmt = try allocator.create(statement.Statement);
            errdefer allocator.destroy(stmt);
            const next_pos = try stmt.init(tokens, current_pos, allocator);
            current_pos = next_pos;

            arrl.append(stmt) catch {
                return ParseError.Error;
            };
        }

        target.* = .{
            // FIXME: is this copying the whole arraylist? should use a pointer?
            .statements = arrl,
            .alloc = allocator,
        };
    }

    pub fn deinit(self: @This()) void {
        // FIXME: should deinit all elements inside the arraylist no? otherwise
        // they will leak no?
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

    std.debug.print("len: {d} \n", .{module.statements.items.len});
    defer module.deinit();
}
