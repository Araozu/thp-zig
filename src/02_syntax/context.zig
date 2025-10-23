const std = @import("std");
const lexic = @import("lexic");
const types = @import("./types.zig");
const context = @import("context");

const Token = lexic.Token;
const TokenType = lexic.TokenType;
const ParseError = types.ParseError;
const TokenStream = types.TokenStream;

pub const ParserContext = struct {
    allocator: std.mem.Allocator,
    tokens: *const TokenStream,
    err: *context.ErrorContext,

    /// Returns true if `pos` is greater than the number of tokens
    pub fn oob(self: *const ParserContext, pos: usize) bool {
        return pos >= self.tokens.items.len;
    }
};
