# tree-sitter-commodore-basic

One grammar for two Commodore dialects:

- **BASIC 2.0** (VIC-20 and C64), highlighted by the Commodore BASIC language
- **BASIC65** (MEGA65), highlighted by the BASIC65 language

Keywords are case-insensitive. The external scanner keeps the longest keyword that is a prefix of the following letters, then leaves the rest for the next token. That is how the machines crunch a line: `FORI` is `FOR` + `I`, and `TOTAL` is `TO` + `TAL`. `REM` consumes the rest of the line, including colons. PETSCII `{codes}` are nodes inside strings.

BASIC 2.0 words are `keyword` nodes. BASIC65-only words are `basic65_keyword` nodes. Each language's `highlights.scm` decides how to paint them. `petcat -w2` leaves BASIC65-only words as plain text, so Commodore BASIC paints those nodes as variables.

The generated parser is ABI 15 (`tree-sitter-cli` 0.27.1), which matches the tree-sitter crate Zed compiles with.

```bash
cd grammars/tree-sitter-commodore-basic
npx --yes tree-sitter-cli@0.27.1 generate
npx --yes tree-sitter-cli@0.27.1 test
```
