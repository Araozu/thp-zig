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
};
