const std = @import("std");
const syntax = @import("syntax");
const semantic = @import("semantic");

const Statement = syntax.Statement;
const VariableBinding = syntax.VariableBinding;
const ASTModule = syntax.Module;

const Visitor = semantic.Visitor;

pub const PHPGeneratorVisitor = struct {
    alloc: std.mem.Allocator,
    bytes: std.ArrayListUnmanaged(u8),

    pub fn init(alloc: std.mem.Allocator) PHPGeneratorVisitor {
        return PHPGeneratorVisitor{
            .alloc = alloc,
            .bytes = .empty,
        };
    }

    pub fn visitStatement(ptr: *anyopaque, node: *const Statement) void {
        const self: *PHPGeneratorVisitor = @ptrCast(@alignCast(ptr));

        switch (node.value) {
            .variableBinding => |b| {
                b.accept(&self.visitor());
            },
        }
    }

    pub fn visitVariableBinding(ptr: *anyopaque, node: *const VariableBinding) void {
        const self: *PHPGeneratorVisitor = @ptrCast(@alignCast(ptr));

        const out = std.fmt.allocPrint(self.alloc, "${s} = ??", .{node.identifier.value}) catch {
            @panic("fmt error");
        };
        defer self.alloc.free(out);

        self.bytes.appendSlice(self.alloc, out) catch {
            @panic("append error. so sad.");
        };
    }

    pub fn visitor(self: *PHPGeneratorVisitor) Visitor {
        return Visitor{
            .ptr = self,
            .visitStatementFn = visitStatement,
            .visitVariableBindingFn = visitVariableBinding,
        };
    }
};

pub fn gen_php(alloc: std.mem.Allocator, ast: *const ASTModule) void {
    var codegen_visitor = PHPGeneratorVisitor.init(alloc);
    const v = codegen_visitor.visitor();

    // walk
    for (ast.statements.items) |*statement| {
        statement.accept(&v);
    }

    // print
    std.debug.print("{s}", .{codegen_visitor.bytes.items});
}

test {
    std.testing.refAllDecls(@This());
}
