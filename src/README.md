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


## CLI

```
thp         - starts the REPL?
thp dev     - starts the dev server, picking up the config file
thp build   - builds the project based on the config file

thp init    - creates a new config file
thp compile - compiles a single file, outputs to stdout
    c

thp lex     - lexes a single file, outputs tokens to stdout as json

<compile> options

thp c <file>             - compiles a single file, outputs to stdout
      <file> -o <output> - compiles a single file, outputs to <output>
      <file> -i          - compiles a single file in place. the output file is the input file with .php extension

```


## Memory management

The compiler holds 2 context objects for the duration of the compilation:

- `ErrorContext` - holds errors and warnings for the compiler pipeline.
  It holds an allocator and a list of errors/warnings.
- `ParserContext` - holds the symbol table and other state for the compiler.
  It holds an allocator, a token stream and the error context.


