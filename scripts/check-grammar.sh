#!/usr/bin/env bash
# Generate the Commodore BASIC parser, fail if that drifts from git,
# run the corpus, and validate the Zed highlight queries.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRAM="$ROOT/grammars/tree-sitter-commodore-basic"
TS=(npx --yes tree-sitter-cli@0.27.1)

cd "$GRAM"
"${TS[@]}" generate
git -C "$ROOT" diff --exit-code -- grammars/tree-sitter-commodore-basic/src grammars/tree-sitter-commodore-basic/grammar.js
"${TS[@]}" test

query() {
  local scm="$1"
  shift
  "${TS[@]}" query -p "$GRAM" "$scm" "$@" >/dev/null
}

query "$ROOT/languages/commodore-basic/highlights.scm" \
  "$ROOT/examples/basic2.bas" \
  "$ROOT/examples/basic65.b65" \
  "$ROOT/color-demo.m65"
query "$ROOT/languages/basic65/highlights.scm" \
  "$ROOT/examples/basic2.bas" \
  "$ROOT/examples/basic65.b65" \
  "$ROOT/color-demo.m65"
query "$ROOT/languages/commodore-basic/brackets.scm" "$ROOT/examples/basic2.bas"
query "$ROOT/languages/basic65/brackets.scm" "$ROOT/examples/basic65.b65"
query "$ROOT/languages/commodore-basic/outline.scm" "$ROOT/color-demo.m65"
query "$ROOT/languages/basic65/outline.scm" "$ROOT/color-demo.m65"

# Dialect split: BASIC65-only words are names in Commodore BASIC and
# keywords in BASIC65. The cruncher splits TOTAL into TO + TAL.
basic2="$("${TS[@]}" query -p "$GRAM" "$ROOT/languages/commodore-basic/highlights.scm" "$ROOT/examples/basic2.bas")"
basic65_as_cbm="$("${TS[@]}" query -p "$GRAM" "$ROOT/languages/commodore-basic/highlights.scm" "$ROOT/examples/basic65.b65")"
basic65_as_b65="$("${TS[@]}" query -p "$GRAM" "$ROOT/languages/basic65/highlights.scm" "$ROOT/examples/basic65.b65")"
demo="$("${TS[@]}" query -p "$GRAM" "$ROOT/languages/basic65/highlights.scm" "$ROOT/color-demo.m65")"

printf '%s\n' "$basic2" | grep -E 'keyword, .*text: `to`' >/dev/null
printf '%s\n' "$basic2" | grep -E 'variable, .*text: `tal`' >/dev/null
printf '%s\n' "$basic2" | grep -E 'string.special, .*text: `\{clr\}`' >/dev/null
printf '%s\n' "$basic65_as_cbm" | grep -E 'variable, .*text: `speed`' >/dev/null
printf '%s\n' "$basic65_as_cbm" | grep -E 'variable, .*text: `graphic`' >/dev/null
printf '%s\n' "$basic65_as_cbm" | grep -E 'keyword, .*text: `print`' >/dev/null
if printf '%s\n' "$basic65_as_cbm" | grep -E 'keyword, .*text: `speed`' >/dev/null; then
  echo "BASIC65-only SPEED was painted as a keyword in Commodore BASIC" >&2
  exit 1
fi
printf '%s\n' "$basic65_as_b65" | grep -E 'keyword, .*text: `speed`' >/dev/null
printf '%s\n' "$basic65_as_b65" | grep -E 'keyword, .*text: `graphic`' >/dev/null
printf '%s\n' "$basic65_as_b65" | grep -E 'string.special, .*text: `\{swlc\}`' >/dev/null
printf '%s\n' "$demo" | grep -E 'comment, .*text: `rem ' >/dev/null

echo "grammar, corpus, and queries ok"
