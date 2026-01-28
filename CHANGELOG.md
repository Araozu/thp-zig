# Typed Hypertext Preprocessor

The latest & greatest rewrite of the THP programming language.
Now in Zig!

This is a rough, non-commital roadmap of sorts.

## TODO

- [ ] Rewrite CLI interface
- [ ] Rewrite REPL
- [ ] Type definition generator
- [ ] Code formatter
- [ ] stdlib
- [ ] Watch mode compilation
- [ ] Project mode compilation
- [ ] Docs generator
- [ ] Parse function call w arguments
- [ ] Parse unary ops
- [ ] Parse conditionals
- [ ] Parse multiple statements
- [ ] Define & implement ASI - automatic semicolon insertion
- [ ] Parse function declaration
- [ ] Restore REPL interface
- [ ] Add tests to semantic analysis/codegen
- [ ] Implement more semantic phases
- [ ] Test memory errors w failing allocator
- [ ] Typecheck function call
- [ ] vm: support more datatypes
- [ ] IR lowering
- [ ] req: IR lowering | number promotion
- [ ] req: IR lowering | number casts
- [ ] more datatypes: i8, i16, i32, i64, u8, u16, u32, u64, f32
- [ ] parse conditionals
- [ ] vm: conditionals

## v0.0.5: rewritten again

- [x] remove stack based vm
- [x] target register based vm


## v0.0.4: typed

- [x] runtime strings
- [x] cast numbers to string
- [x] Operator `++` coerces to string
- [x] Builtin `print` coerces to string
- [x] vm: variables

## v0.0.3: hello world

- [x] parse binary operators
- [x] regression: reenable function call parsing
- [x] typed & overloaded binary operators
- [x] create id for AST nodes
- [x] store type info
- [x] more datatypes: f64, u64
- [x] constant strings
- [x] vm: binary operators
- [x] print strings


## v0.0.2: bare minimum

- [x] Define how the CLI will operate
- [x] Create a proper pipeline for the CLI
- [x] Pipeline for reading file from stdin & emitting to stdout
- [x] Proper error reporting on semantic analysis
- [x] Extract expression typechecking
- [x] Parse variable type hint
- [x] Parse function call (simple)
- [x] Register identifier in symbol table
- [x] Typecheck identifier w symbol table
- [x] Small VM
- [x] vm: Emit simple bytecode
- [x] Parse function call with argument
- [x] vm: `print` compiler builtin
- [x] vm: Read, parse & interpret bytecode
- [x] emit bytecode for minimal print


## v0.0.1: hopes & dreams

- [x] Lex numbers
- [x] Lex identifier
- [x] Lex datatypes
- [x] Lex operators
- [x] Lex single line comments
- [x] Lex strings
- [x] Lex grouping signs
- [x] Parse minimal expression
- [x] Parse minimal variable binding
- [x] Parse minimal statement
- [x] Parse minimal module
- [x] Recover errors & generate error messages for the lexer
- [x] Serialize lex errors/tokens into JSON
- [x] Rewrite lexer
- [x] Rewrite tests
- [x] Rewrite minimal parser
- [x] Rewrite semantic analyzer
- [x] Rewrite type checker
- [x] Rewrite code generator
