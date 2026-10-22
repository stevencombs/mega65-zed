// Commodore BASIC, tokenized the way the machines do it.
//
// Keywords are case-insensitive. The external scanner keeps the longest
// keyword that is a prefix of the following letters, then leaves the rest
// for the next token. That is the C64/VIC-20/MEGA65 cruncher: FORI is
// FOR + I, and TOTAL is TO + TAL. REM consumes the rest of the line,
// including colons. PETSCII {codes} are nodes inside strings.
//
// One grammar covers both dialects. BASIC 2.0 words are `keyword` nodes.
// BASIC65-only words are `basic65_keyword` nodes. Each language's
// highlights.scm decides how to paint them.

/// <reference types="tree-sitter-cli/dsl" />

module.exports = grammar({
  name: "commodore_basic",

  // Spaces outside strings are trivia. Inside a string, token.immediate
  // keeps spaces and {PETSCII} codes in the string instead of skipping them.
  extras: ($) => [/[ \t]+/],

  externals: ($) => [
    $.keyword,
    $.basic65_keyword,
    $.identifier,
    $.rem_statement,
    $.petscii_code,
    $.string_content,
  ],

  rules: {
    source_file: ($) =>
      seq(
        repeat(choice(seq($.line, $._newline), $._newline)),
        optional($.line),
      ),

    line: ($) =>
      choice(
        prec(2, seq($.line_number, optional($.statements))),
        prec(1, $.statements),
      ),

    // Higher lexical precedence than `number` so a leading 10 is a line
    // number when both tokens are valid. Inside a statement only `number`
    // is valid.
    line_number: ($) => token(prec(2, /[0-9]+/)),

    statements: ($) =>
      seq(
        $.statement,
        repeat(seq(alias(":", $.punctuation), $.statement)),
      ),

    statement: ($) => choice($.rem_statement, repeat1($._atom)),

    _atom: ($) =>
      choice(
        $.keyword,
        $.basic65_keyword,
        $.identifier,
        $.number,
        $.string,
        $.operator,
        $.punctuation,
        alias("?", $.keyword),
      ),

    // Bodies are unused. The external scanner emits these nodes.
    keyword: ($) => token("keyword"),
    basic65_keyword: ($) => token("basic65_keyword"),
    identifier: ($) => token("identifier"),
    rem_statement: ($) => token("rem"),

    number: ($) =>
      token(
        prec(
          1,
          choice(
            /\$[0-9A-Fa-f]+/,
            /%[01]+/,
            /[0-9]+\.[0-9]*([Ee][+-]?[0-9]+)?/,
            /\.[0-9]+([Ee][+-]?[0-9]+)?/,
            /[0-9]+[Ee][+-]?[0-9]+/,
            /[0-9]+/,
          ),
        ),
      ),

    // A following quote closes the string (`""` is empty). The scanner
    // prefers petscii_code / string_content over keywords while those
    // symbols are valid, so letters inside quotes stay in the string.
    string: ($) =>
      prec.right(
        seq(
          '"',
          repeat(choice($.petscii_code, $.string_content)),
          optional('"'),
        ),
      ),

    petscii_code: ($) => token("petscii"),
    string_content: ($) => token("string_content"),

    operator: ($) =>
      choice(
        "<>",
        "<=",
        ">=",
        "=<",
        "=>",
        "<<",
        ">>",
        "+",
        "-",
        "*",
        "/",
        "^",
        "=",
        "<",
        ">",
      ),

    punctuation: ($) => choice(",", ";", "(", ")"),

    _newline: ($) => /\r?\n|\r/,
  },
});
