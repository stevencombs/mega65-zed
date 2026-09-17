#!/usr/bin/env bash
# Unprefixed names in ~/m65tools (etherload, m65, …) and xmega65 on PATH.
set -euo pipefail
TOOLS="${M65TOOLS:-$HOME/m65tools}"
if [[ ! -d "$TOOLS" ]]; then
  echo "No $TOOLS directory." >&2
  exit 1
fi
cd "$TOOLS"
for f in etherload m65 mega65_ftp bit2core bit2mcs romdiff; do
  if [[ -x "${f}.osx" ]]; then
    ln -sfn "${f}.osx" "$f"
    echo "  $f → ${f}.osx"
  fi
done
mkdir -p "$HOME/.local/bin"
if [[ -x /Applications/xmega65.app/Contents/MacOS/xmega65 ]]; then
  ln -sfn /Applications/xmega65.app/Contents/MacOS/xmega65 "$HOME/.local/bin/xmega65"
  echo "  xmega65 → /Applications/xmega65.app"
fi
echo "Add to PATH (already in chezmoi dot_zshrc):  export PATH=\"\$HOME/m65tools:\$PATH\""
echo "New shells pick it up. This shell:  export PATH=\"$TOOLS:\$PATH\""
