#!/usr/bin/env bash
# Install petcat and (when a build exists) mega65-tools for macOS and Linux.
# Tools go in ~/.retrocombs-m65/bin. Does not install Homebrew, Zed, or Rosetta.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/cbm-tools.sh
source "$ROOT/scripts/cbm-tools.sh"

BIN="${CBM_BIN_DIR:-$HOME/.retrocombs-m65/bin}"
PETCAT_URL="${PETCAT_URL:-https://files.mega65.org/files/p/petcat-20230619_6Veruh.zip}"

echo "retroCombs Commodore BASIC tools  (extension 0.7.0)"
echo "OS: $(uname -s) $(uname -m)"
echo "Bin: $BIN"
echo "This does not install Zed, Homebrew, or Rosetta."
echo

mkdir -p "$BIN"
cp "$ROOT/scripts/mega65.sh" "$BIN/mega65.sh"
cp "$ROOT/scripts/cbm-tools.sh" "$BIN/cbm-tools.sh"
chmod +x "$BIN/mega65.sh" "$BIN/cbm-tools.sh"
echo "Installed mega65.sh and cbm-tools.sh"

echo
echo "petcat from $PETCAT_URL"
tmp="$(mktemp -d)"
if ! curl -fL --max-time 180 -o "$tmp/petcat.zip" "$PETCAT_URL"; then
  echo "Could not download petcat." >&2
  rm -rf "$tmp"
  exit 1
fi
if ! cbm_install_petcat_from_zip "$tmp/petcat.zip" "$BIN/petcat"; then
  rm -rf "$tmp"
  exit 1
fi
rm -rf "$tmp"
echo "Installed $BIN/petcat"

echo
os_tag="$(cbm_host_os_tag || true)"
tool_url="${M65TOOLS_URL:-}"
if [[ -z "$tool_url" && -n "$os_tag" ]]; then
  echo "Looking up MEGA65/mega65-tools releases for $os_tag"
  tool_url="$(cbm_github_m65tools_urls | cbm_pick_m65tools_url "$os_tag" || true)"
fi
if [[ -z "$tool_url" ]]; then
  echo "No mega65-tools archive for this OS."
  echo "The CI-development-latest tag has often published macOS archives only."
  echo "Set M65TOOLS_URL to a .7z or .zip, or copy etherload into $BIN."
  echo "https://github.com/MEGA65/mega65-tools/releases"
  echo "https://files.mega65.org"
else
  echo "mega65-tools: $tool_url"
  ttmp="$(mktemp -d)"
  archive="$ttmp/$(basename "$tool_url")"
  if curl -fL --max-time 300 -o "$archive" "$tool_url"; then
    if cbm_extract_archive "$archive" "$ttmp/out"; then
      if cbm_install_tree_tool "$ttmp/out" "$BIN/etherload" etherload etherload.osx; then
        echo "Installed $BIN/etherload"
      else
        echo "Archive had no etherload or etherload.osx (etherload.prg is skipped)."
      fi
      if cbm_install_tree_tool "$ttmp/out" "$BIN/m65" m65 m65.osx; then
        echo "Installed $BIN/m65"
      fi
      if cbm_install_tree_tool "$ttmp/out" "$BIN/mega65_ftp" mega65_ftp mega65_ftp.osx; then
        echo "Installed $BIN/mega65_ftp"
      fi
    else
      echo "Could not extract mega65-tools. etherload was not installed."
    fi
  else
    echo "Could not download mega65-tools. etherload was not installed."
  fi
  rm -rf "$ttmp"
fi

echo
if [[ -x /Applications/xmega65.app/Contents/MacOS/xmega65 ]]; then
  ln -sfn "/Applications/xmega65.app/Contents/MacOS/xmega65" "$BIN/xmega65"
  echo "Linked $BIN/xmega65 → /Applications/xmega65.app"
elif [[ -x "$HOME/Applications/xmega65.app/Contents/MacOS/xmega65" ]]; then
  ln -sfn "$HOME/Applications/xmega65.app/Contents/MacOS/xmega65" "$BIN/xmega65"
  echo "Linked $BIN/xmega65 → ~/Applications/xmega65.app"
else
  echo "xmega65.app not found. XEMU tasks work once XMEGA65 or XMEGA65_APP is set."
fi

echo
cbm_install_path_snippets
echo "PATH snippet is in the shell rc file under ~/.retrocombs-m65/bin (prepended)."
echo "Open a new terminal, or: export PATH=\"\$HOME/.retrocombs-m65/bin:\$PATH\""

echo
if [[ ! -x "$BIN/petcat" ]]; then
  echo "petcat is missing." >&2
  exit 1
fi
if "$BIN/petcat" -k </dev/null 2>&1 | grep -qi petcat; then
  echo "petcat responds."
else
  echo "petcat is installed. '-k' did not print a version banner; trying a tokenize later will tell you if it runs."
fi
if [[ -x "$BIN/etherload" ]]; then
  echo "etherload is installed."
else
  echo "etherload is not installed. Push to hardware needs it. Emulator tasks do not."
fi
echo
echo "Done. In Zed, install this folder as a dev extension, then open a .bas or .b65 file."
