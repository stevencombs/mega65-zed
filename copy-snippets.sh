#!/usr/bin/env bash
# Snippets ship inside the extension (snippets/commodore basic.json
# and snippets/basic65.json). This script does not copy them into
# ~/.config/zed/snippets, and it does not touch plaintext.json unless
# you pass --remove-stale and that file is the old PETSCII copy.
set -euo pipefail

DEST="${ZED_SNIPPETS_DIR:-$HOME/.config/zed/snippets}"

usage() {
  cat >&2 <<EOF
usage: $(basename "$0") [--remove-stale]

Snippets load from the extension. Nothing is copied.

--remove-stale deletes old user snippet files that used to shadow or
miss the language names:
  cbm basic.json, cbm-basic.json, mega65 basic.json,
  vic20 basic.json, vic-20 basic.json, c64 basic.json, c64-basic.json,
  plaintext_old.json, snippets.json
plaintext.json is removed only when it contains the old marker
  Clear screen + home  CHR\$(147)
EOF
  exit 2
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi
if [[ -n "${1:-}" && "${1:-}" != "--remove-stale" ]]; then
  usage
fi

echo "Commodore BASIC snippets live in the extension:"
echo "  snippets/commodore basic.json   (.bas, VIC-20 and C64)"
echo "  snippets/basic65.json           (.b65 and .m65)"
echo "User snippet dir (not modified unless --remove-stale): $DEST"

if [[ "${1:-}" != "--remove-stale" ]]; then
  echo "Pass --remove-stale to delete the old user copies."
  exit 0
fi

if [[ ! -d "$DEST" ]]; then
  echo "No snippet directory at $DEST"
  exit 0
fi

stale=(
  "cbm basic.json"
  "cbm-basic.json"
  "mega65 basic.json"
  "vic20 basic.json"
  "vic-20 basic.json"
  "c64 basic.json"
  "c64-basic.json"
  "plaintext_old.json"
  "snippets.json"
)

for name in "${stale[@]}"; do
  if [[ -f "$DEST/$name" ]]; then
    rm -f "$DEST/$name"
    echo "removed $DEST/$name"
  fi
done

plain="$DEST/plaintext.json"
marker='Clear screen + home  CHR$(147)'
if [[ -f "$plain" ]] && grep -qF "$marker" "$plain"; then
  rm -f "$plain"
  echo "removed $plain (old PETSCII copy)"
elif [[ -f "$plain" ]]; then
  echo "left $plain in place (it does not look like the old PETSCII copy)"
fi
