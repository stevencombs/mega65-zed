#!/usr/bin/env bash
# Unprefixed names (etherload, m65, ...) next to the .osx binaries,
# and an xmega65 symlink when the Mac app bundle is installed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cbm-tools.sh
source "$HERE/cbm-tools.sh"

TOOLS="${M65TOOLS:-$HOME/m65tools}"
if [[ ! -d "$TOOLS" ]]; then
  echo "No $TOOLS directory. Unpack mega65-tools there, or set M65TOOLS." >&2
  exit 1
fi

cd "$TOOLS"
for f in etherload m65 mega65_ftp bit2core bit2mcs romdiff; do
  if [[ -x "${f}.osx" ]]; then
    ln -sfn "${f}.osx" "$f"
    echo "  $f → ${f}.osx"
  fi
done

BIN="${CBM_BIN_DIR:-$HOME/.retrocombs-m65/bin}"
mkdir -p "$BIN"
if [[ -x /Applications/xmega65.app/Contents/MacOS/xmega65 ]]; then
  ln -sfn /Applications/xmega65.app/Contents/MacOS/xmega65 "$BIN/xmega65"
  echo "  xmega65 → /Applications/xmega65.app"
elif [[ -x "$HOME/Applications/xmega65.app/Contents/MacOS/xmega65" ]]; then
  ln -sfn "$HOME/Applications/xmega65.app/Contents/MacOS/xmega65" "$BIN/xmega65"
  echo "  xmega65 → ~/Applications/xmega65.app"
fi
echo "Discovery also checks $TOOLS without these links."
echo "This shell:  export PATH=\"$BIN:\$PATH\""
