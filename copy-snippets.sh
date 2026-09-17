#!/usr/bin/env bash
# Copy MEGA65 PETSCII snippets into Zed's user snippet dir.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)/snippets"
DEST="${HOME}/.config/zed/snippets"
mkdir -p "$DEST"
cp "$SRC/mega65 basic.json" "$DEST/mega65 basic.json"
# Plain Text fallback (Zed dev extensions can miss language-scoped snippets)
cp "$SRC/mega65 basic.json" "$DEST/plaintext.json"
echo "MEGA65 snippets → $DEST"
echo "In a .m65 buffer, type red / graphic / 10print then Tab."
