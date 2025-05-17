const std = @import("std");
const lexic = @import("lexic");
const syntax = @import("syntax");
const context = @import("context");

const types = @import("../types.zig");
const visitor = @import("../visitor.zig");

const ErrorCtx = context.ErrorContext;
const StringHashMap = std.StringHashMapUnmanaged;
const Scope = types.Scope;
const Type = types.Type;
const Visitor = visitor.Visitor;
const VisitorError = visitor.VisitorError;

const Statement = syntax.Statement;
const VariableBinding = syntax.VariableBinding;

pub const SymbolCollectorVisitor = struct {
    scope: *Scope,
    alloc: std.mem.Allocator,
    err: *ErrorCtx,

    pub fn init(
        alloc: std.mem.Allocator,
        s: *Scope,
        err: *ErrorCtx,
    ) SymbolCollectorVisitor {
        return SymbolCollectorVisitor{
            .scope = s,
            .alloc = alloc,
            .err = err,
        };
    }

    pub fn visitStatement(ptr: *anyopaque, node: *const Statement) VisitorError!void {
        const self: *SymbolCollectorVisitor = @ptrCast(@alignCast(ptr));

        switch (node.value) {
            .variableBinding => |b| {
                try b.accept(&self.visitor());
            },
        }
    }

    pub fn visitVariableBinding(ptr: *anyopaque, node: *const VariableBinding) VisitorError!void {
        const self: *SymbolCollectorVisitor = @ptrCast(@alignCast(ptr));

        const variable_name = node.identifier.value;
        if (self.scope.has(variable_name)) {
            // another symbol is already declared

            const offending_token = node.identifier;
            const error_start = offending_token.start_pos;
            const error_end = error_start + offending_token.value.len;

            var new_error = try self.err.create_and_append_error("Duplicated symbol", error_start, error_end);
            try new_error.add_label(self.err.create_error_label("This variable has already been declared on the current scope", error_start, error_end));

            return VisitorError.SemanticError;
        }

        self.scope.insert(
            variable_name,
            .{
                .t = Type.Untyped,
                .location = .{
                    .start = 0,
                    .end = 0,
                },
            },
        ) catch {
            return VisitorError.OutOfMemory;
        };
    }

    pub fn visitor(self: *SymbolCollectorVisitor) Visitor {
        return Visitor{
            .ptr = self,
            .visitStatementFn = visitStatement,
            .visitVariableBindingFn = visitVariableBinding,
        };
    }
};

test "should visit a variable declaration" {
    //
    // Arrange
    //
    var errctx = ErrorCtx.init(std.testing.allocator);
    defer errctx.deinit();
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();
    var symbol_visitor = SymbolCollectorVisitor.init(
        std.testing.allocator,
        &scope,
        &errctx,
    );

    // variable binding
    const t = try lexic.tokenize("var identifier = 322", std.testing.allocator, &errctx);
    defer t.deinit();
    var ctx = syntax.context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &t,
        .err = &errctx,
    };

    var stmt: Statement = undefined;
    _ = try stmt.init(0, &ctx) orelse unreachable;
    defer stmt.deinit(&ctx);

    //
    // Act
    //

    try symbol_visitor.visitor().visitStatement(&stmt);

    //
    // Assert
    //

    try std.testing.expect(scope.has("identifier"));
    try std.testing.expectEqual(Type.Untyped, scope.get("identifier").?.t);
}

test "should visit two variable declarations" {
    //
    // Arrange
    //
    var errctx = ErrorCtx.init(std.testing.allocator);
    defer errctx.deinit();
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();
    var symbol_visitor = SymbolCollectorVisitor.init(
        std.testing.allocator,
        &scope,
        &errctx,
    );

    // variable binding
    const token_stream = try lexic.tokenize("var first = 322 var second = 644", std.testing.allocator, &errctx);
    defer token_stream.deinit();
    var ctx = syntax.context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &token_stream,
        .err = &errctx,
    };

    var stmt1: Statement = undefined;
    _ = try stmt1.init(0, &ctx) orelse unreachable;
    defer stmt1.deinit(&ctx);

    var stmt2: Statement = undefined;
    _ = try stmt2.init(4, &ctx) orelse unreachable;
    defer stmt2.deinit(&ctx);

    //
    // Act
    //
    try symbol_visitor.visitor().visitStatement(&stmt1);
    try symbol_visitor.visitor().visitStatement(&stmt2);

    //
    // Assert
    //
    try std.testing.expect(scope.has("first"));
    try std.testing.expectEqual(Type.Untyped, scope.get("first").?.t);

    try std.testing.expect(scope.has("second"));
    try std.testing.expectEqual(Type.Untyped, scope.get("second").?.t);
}

test "should fail on duplicated declaration" {
    //
    // Arrange
    //
    var errctx = ErrorCtx.init(std.testing.allocator);
    defer errctx.deinit();
    var scope = Scope.init(std.testing.allocator);
    defer scope.deinit();
    var symbol_visitor = SymbolCollectorVisitor.init(
        std.testing.allocator,
        &scope,
        &errctx,
    );

    // variable binding
    const token_stream = try lexic.tokenize("var first = 322 var first = 644", std.testing.allocator, &errctx);
    defer token_stream.deinit();
    var ctx = syntax.context.ParserContext{
        .allocator = std.testing.allocator,
        .tokens = &token_stream,
        .err = &errctx,
    };

    var stmt1: Statement = undefined;
    _ = try stmt1.init(0, &ctx) orelse unreachable;
    defer stmt1.deinit(&ctx);

    var stmt2: Statement = undefined;
    _ = try stmt2.init(4, &ctx) orelse unreachable;
    defer stmt2.deinit(&ctx);

    //
    // Act
    //
    try symbol_visitor.visitor().visitStatement(&stmt1);
    symbol_visitor.visitor().visitStatement(&stmt2) catch |e| switch (e) {
        //
        // Asert
        //
        error.SemanticError => {
            try std.testing.expect(true);
            return;
        },
        else => {
            try std.testing.expect(false);
            return;
        },
    };
}
