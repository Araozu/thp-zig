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
            var new_error = try self.err.create_and_append_error("Duplicated symbol", 0, 1);
            try new_error.add_label(self.err.create_error_label("This variable has already been declared on the current scope", 0, 1));

            return VisitorError.SemanticError;
        }

        self.scope.insert(variable_name, Type.Untyped) catch {
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

test "test symbol visitor 1" {
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
    try std.testing.expectEqual(Type.Untyped, scope.get("identifier").?);
}
