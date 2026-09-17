#!/usr/bin/env bash
# MEGA65 BASIC65: check / run / push / push-run
# Tokenize with VICE petcat -w65 (load $2001). Hardware via mega65-tools etherload.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PETCAT="${PETCAT:-/opt/homebrew/bin/petcat}"
ETHERLOAD="${ETHERLOAD:-$HOME/.retrocombs-m65/bin/etherload}"
XMEGA65_APP="${XMEGA65_APP:-/Applications/xmega65.app}"
LOAD_HEX="${CBM_MEGA65_LOAD:-2001}"

usage() {
  echo "usage: $(basename "$0") check|run|push|push-run [listing.m65]" >&2
  exit 2
}

program_dir() {
  local f="${1:-}"
  if [[ -z "$f" || "$f" == *"\$ZED_FILE"* ]]; then
    echo "Open a .m65 listing first." >&2
    exit 1
  fi
  [[ "$f" == /* ]] || f="$PWD/$f"
  local d
  d="$(cd "$(dirname "$f")" && pwd)"
  if [[ "$(basename "$d")" == "src" ]]; then
    dirname "$d"
    return
  fi
  echo "$d"
}

stem_of() {
  local f="$1"
  local b
  b="$(basename "$f")"
  echo "${b%.*}"
}

find_source() {
  local dir="$1"
  local stem="$2"
  if [[ -f "$dir/src/${stem}.m65" ]]; then
    echo "$dir/src/${stem}.m65"
    return
  fi
  if [[ -f "$dir/${stem}.m65" ]]; then
    echo "$dir/${stem}.m65"
    return
  fi
  local hit
  hit="$(ls "$dir"/src/*.m65 "$dir"/*.m65 2>/dev/null | head -1 || true)"
  if [[ -z "$hit" ]]; then
    echo "No .m65 in $dir" >&2
    exit 1
  fi
  echo "$hit"
}

tokenize() {
  local dir="$1"
  local src="$2"
  local stem
  stem="$(stem_of "$src")"
  mkdir -p "$dir/export"
  local prg="$dir/export/${stem}.prg"
  echo "petcat -w65  ($src) → $prg" >&2
  "$PETCAT" -w65 -f -o "$prg" -- "$src"
  echo "PRG $prg  load \$$LOAD_HEX  $(wc -c < "$prg" | tr -d ' ') bytes" >&2
  # keep legacy name for old muscle memory
  cp "$prg" "$dir/build.prg"
  echo "$prg"
}

cmd="${1:-}"
file="${2:-}"
[[ -n "$cmd" ]] || usage

dir="$(program_dir "$file")"
[[ "$file" == /* ]] || file="$PWD/$file"
src="$file"
if [[ ! -f "$src" ]]; then
  src="$(find_source "$dir" "$(stem_of "$file")")"
fi

case "$cmd" in
  check)
    tokenize "$dir" "$src" >/dev/null
    echo "Check OK. Review the listing; Push is your key, not Grok's."
    ;;
  run)
    prg="$(tokenize "$dir" "$src")"
    if [[ ! -d "$XMEGA65_APP" ]]; then
      echo "xmega65.app not found in /Applications." >&2
      exit 1
    fi
    echo "Launching XEMU xmega65 with $prg"
    open -na "$XMEGA65_APP" --args -prg "$prg"
    ;;
  push)
    prg="$(tokenize "$dir" "$src")"
    if [[ ! -x "$ETHERLOAD" ]]; then
      echo "etherload not found at $ETHERLOAD (run mega65zed-install.sh)." >&2
      exit 1
    fi
    echo "etherload (load, do not RUN)  $prg"
    "$ETHERLOAD" "$prg"
    echo "On the MEGA65 you should be at READY. Type RUN if you want it to go."
    ;;
  push-run)
    prg="$(tokenize "$dir" "$src")"
    if [[ ! -x "$ETHERLOAD" ]]; then
      echo "etherload not found at $ETHERLOAD (run mega65zed-install.sh)." >&2
      exit 1
    fi
    echo "etherload -r  $prg"
    "$ETHERLOAD" -r "$prg"
    ;;
  *)
    usage
    ;;
esac
