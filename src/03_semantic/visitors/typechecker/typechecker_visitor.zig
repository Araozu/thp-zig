const std = @import("std");
const lexic = @import("lexic");
const syntax = @import("syntax");
const context = @import("context");

const types = @import("../../types.zig");
const symbol_table = @import("../../symbol_table.zig");
const visitor = @import("../../visitor.zig");
const m_semantic_context = @import("../../semantic_context.zig");

const TokenType = lexic.TokenType;
const ErrorCtx = context.ErrorContext;
const StringHashMap = std.StringHashMapUnmanaged;
const Scope = types.Scope;
const Type = types.Type;
const Visitor = visitor.Visitor;
const VisitorError = visitor.VisitorError;
const SymbolTable = symbol_table.SymbolTable;

const Statement = syntax.Statement;
const VariableBinding = syntax.VariableBinding;

const expressionVisitor = @import("./expression_visitor.zig");

pub const TypecheckerVisitor = struct {
    symbol_table: *const SymbolTable,
    scope: *Scope,
    alloc: std.mem.Allocator,
    semantic_ctx: *m_semantic_context.SemanticContext,
    err: *ErrorCtx,

    pub fn init(
        alloc: std.mem.Allocator,
        table: *const SymbolTable,
        s: *Scope,
        semantic_ctx: *m_semantic_context.SemanticContext,
        err: *ErrorCtx,
    ) TypecheckerVisitor {
        return TypecheckerVisitor{
            .scope = s,
            .symbol_table = table,
            .alloc = alloc,
            .semantic_ctx = semantic_ctx,
            .err = err,
        };
    }

    pub fn visitStatement(ptr: *anyopaque, node: *const Statement) VisitorError!Type {
        const self: *TypecheckerVisitor = @ptrCast(@alignCast(ptr));

        switch (node.*) {
            .variableBinding => |binding| {
                return try binding.accept(Type, &self.visitor());
            },
            .expression => |expression| {
                return try expression.accept(Type, &self.visitor());
            },
        }
    }

    pub fn visitExpression(ptr: *anyopaque, node: *const syntax.PrattExpression) VisitorError!Type {
        const self: *TypecheckerVisitor = @ptrCast(@alignCast(ptr));
        const expr_type = try expressionVisitor.visit(self, node, self.semantic_ctx);
        try self.semantic_ctx.set_type(node.get_id(), expr_type);
        return expr_type;
    }

    /// Always returns Type.Untyped on success
    pub fn visitVariableBinding(ptr: *anyopaque, node: *const VariableBinding) VisitorError!Type {
        const self: *TypecheckerVisitor = @ptrCast(@alignCast(ptr));

        // ensure the binding is on the symbol table
        // get the type of the binding expression
        const expression_type = try expressionVisitor.visit(self, &node.expression, self.semantic_ctx);

        // get the type of the type hint, if any
        const hinted_type = if (node.datatype) |type_hint| switch (type_hint.token_type) {
            // Should match against Datatype and parse its value...
            .Datatype => blk: {
                // look for the type in the global builtin types

                const t = self.symbol_table.lookup_type(type_hint.value) orelse {
                    // TODO: return a proper error
                    std.debug.panic("Type hint not found", .{});
                };

                break :blk t;
            },
            else => {
                std.debug.panic("not implemented: other datatypes during typechecking", .{});
            },
        } else Type.Untyped;

        // check types
        // TODO: should allow safe upcasting
        if (!hinted_type.is_untyped()) {
            // Assert both the type hint and the actual type are the same
            if (!hinted_type.eql(&expression_type)) {
                // The types differ. Return an error

                const hinted_type_name = hinted_type.to_str();
                const expression_type_name = expression_type.to_str();

                var new_error = try self.err.create_and_append_error(
                    "Type mismatch in variable declaration",
                    node.datatype.?.start_pos,
                    node.datatype.?.end_pos(),
                );

                {
                    const err_msg = try std.fmt.allocPrint(self.err.allocator, "This variable declared type `{s}` here", .{hinted_type_name});
                    const err_msg_label = self.err.create_error_label_alloc(
                        err_msg,
                        node.datatype.?.start_pos,
                        node.datatype.?.end_pos(),
                    );
                    try new_error.add_label(err_msg_label);
                }

                {
                    const expression_range = .{ 0, 1 };
                    // FIXME: reenable computin boundaries of an expression
                    // const expression_range = node.expression.get_range();
                    const err_msg = try std.fmt.allocPrint(self.err.allocator, "But this expression has type `{s}`", .{expression_type_name});
                    const err_msg_label = self.err.create_error_label_alloc(
                        err_msg,
                        expression_range.@"0",
                        expression_range.@"1",
                    );
                    try new_error.add_label(err_msg_label);
                }

                return VisitorError.SemanticError;
            }
        }

        // assign types
        const binding_name = node.identifier.value;
        const existing_symbol = self.scope.get(binding_name) orelse {
            // the node was not inserted on the previous symbol collection phase
            std.debug.panic("Compiler erros: Symbol {s} was not on the symbol table during typechecking...", .{binding_name});
        };

        // Assign the slot number based on if it's a value/ref
        std.debug.assert(existing_symbol.slot_index == null);

        const next_slot_idx: types.RegisterRef = blk: {
            if (expression_type.is_primitive()) {
                const tmp = self.scope.next_val_slot;
                self.scope.next_val_slot += 1;
                break :blk .{ .val = tmp };
            } else {
                const tmp = self.scope.next_ref_slot;
                self.scope.next_ref_slot += 1;
                break :blk .{ .ref = tmp };
            }
        };

        try self.scope.insert(
            binding_name,
            .{
                .t = expression_type,
                .location = .{
                    .start = existing_symbol.location.start,
                    .end = existing_symbol.location.end,
                },
                .slot_index = next_slot_idx,
            },
        );
        try self.semantic_ctx.type_map.put(self.semantic_ctx.allocator, node.id, .{
            .computed_type = expression_type,
        });

        return Type.Untyped;
    }

    pub fn visitor(self: *TypecheckerVisitor) Visitor(Type) {
        return .{
            .ptr = self,
            .visitStatementFn = visitStatement,
            .visitVariableBindingFn = visitVariableBinding,
            .visitExpressionFn = visitExpression,
        };
    }
};
