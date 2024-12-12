const std = @import("std");
const lexic = @import("lexic");

/// Respresents a failure of parsing.
pub const ParseError = error{
    /// The parse operation failed, but it is recoverable.
    /// Other parsers should be considered.
    Unmatched,
    /// The parse operation parsed after a point of no return.
    /// For example, a `var` keyword was found, but then no identifier
    /// The parsing should stop
    Error,
    /// OOM. Fatal error, blows up everything
    OutOfMemory,
};

pub const TokenStream = std.ArrayList(lexic.Token);
