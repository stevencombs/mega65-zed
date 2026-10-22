; Commodore BASIC 2.0. BASIC65-only words stay ordinary names here,
; which is how petcat -w2 leaves them.

(keyword) @keyword
(basic65_keyword) @variable
(rem_statement) @comment
(line_number) @constant
(number) @number
(string) @string
(string_content) @string
(petscii_code) @string.special
(identifier) @variable
(operator) @operator
(punctuation) @punctuation

((identifier) @constant.builtin
  (#match? @constant.builtin "^([Tt][Ii]\\$|[Tt][Ii]|[Ss][Tt])$"))
