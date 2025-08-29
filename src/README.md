# Architecture

Overall architecture is that of a typical compiler:

- Lexical analysis
- Syntax analysis
- Semantic analysis

BUT! instead the language is compiled down to PHP (until i write my own VM).
So then theres other phases:

- IR lowering
- PHP code generation

IR lowering takes the THP AST and desugars it into a IR closer to PHP.


## Memory management

The compiler holds 2 context objects for the duration of the compilation:

- `ErrorContext` - holds errors and warnings for the compiler pipeline.
  It holds an allocator and a list of errors/warnings.
- `ParserContext` - holds the symbol table and other state for the compiler.
  It holds an allocator, a token stream and the error context.


