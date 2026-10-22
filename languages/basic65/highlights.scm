; MEGA65 BASIC65. BASIC 2.0 words and BASIC65-only words are both keywords.

(keyword) @keyword
(basic65_keyword) @keyword
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
