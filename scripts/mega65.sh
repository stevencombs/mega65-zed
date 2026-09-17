#!/usr/bin/env bash
# MEGA65 BASIC65: check / run / push / push-run
# Tokenize with VICE petcat -w65 (load $2001). Hardware via mega65-tools etherload.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
M65TOOLS="${M65TOOLS:-$HOME/m65tools}"
export PATH="$M65TOOLS:$HOME/.local/bin:/opt/homebrew/bin:$PATH"
PETCAT="${PETCAT:-/opt/homebrew/bin/petcat}"
XMEGA65_APP="${XMEGA65_APP:-/Applications/xmega65.app}"
LOAD_HEX="${CBM_MEGA65_LOAD:-2001}"

find_m65tool() {
  local name="$1"
  local c
  for c in "$M65TOOLS/$name" "$M65TOOLS/${name}.osx" "$(command -v "$name" 2>/dev/null || true)"; do
    if [[ -n "$c" && -x "$c" ]]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

usage() {
  echo "usage: $(basename "$0") check|run|push|push-run|push-xemu [listing.bas|.m65]" >&2
  exit 2
}

program_dir() {
  local f="${1:-}"
  if [[ -z "$f" || "$f" == *"\$ZED_FILE"* ]]; then
    echo "Open a .bas or .m65 listing first." >&2
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
  for ext in bas m65; do
    if [[ -f "$dir/src/${stem}.${ext}" ]]; then
      echo "$dir/src/${stem}.${ext}"
      return
    fi
    if [[ -f "$dir/${stem}.${ext}" ]]; then
      echo "$dir/${stem}.${ext}"
      return
    fi
  done
  local hit
  hit="$(ls "$dir"/src/*.bas "$dir"/src/*.m65 "$dir"/*.bas "$dir"/*.m65 2>/dev/null | head -1 || true)"
  if [[ -z "$hit" ]]; then
    echo "No .bas or .m65 in $dir" >&2
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
  run|push-xemu)
    prg="$(tokenize "$dir" "$src")"
    xbin="$XMEGA65_APP/Contents/MacOS/xmega65"
    if [[ ! -x "$xbin" ]]; then
      echo "xmega65 not found at $xbin" >&2
      exit 1
    fi
    echo "Pushing $prg into XEMU (-besure -prg)"
    pkill -x xmega65 2>/dev/null || true
    sleep 0.4
    open -na "$XMEGA65_APP" --args -besure -prg "$prg"
    sleep 1.5
    if ! pgrep -x xmega65 >/dev/null; then
      nohup arch -x86_64 "$xbin" -besure -prg "$prg" \
        >/tmp/cbm-xmega65.log 2>&1 </dev/null &
      disown || true
      sleep 1.5
    fi
    if pgrep -x xmega65 >/dev/null; then
      echo "XEMU is running (pid $(pgrep -x xmega65 | tr '\n' ' '))"
    else
      echo "XEMU failed to start. Log:" >&2
      cat /tmp/cbm-xmega65.log >&2 || true
      exit 1
    fi
    ;;
  push)
    prg="$(tokenize "$dir" "$src")"
    etherload="$(find_m65tool etherload || true)"
    if [[ -z "$etherload" ]]; then
      echo "etherload not found in $M65TOOLS (need etherload or etherload.osx)." >&2
      exit 1
    fi
    echo "Network push via $etherload (load, do not RUN)"
    "$etherload" "$prg"
    echo "On the MEGA65 you should be at READY. Type RUN if you want it to go."
    ;;
  push-run)
    prg="$(tokenize "$dir" "$src")"
    etherload="$(find_m65tool etherload || true)"
    if [[ -z "$etherload" ]]; then
      echo "etherload not found in $M65TOOLS (need etherload or etherload.osx)." >&2
      exit 1
    fi
    echo "Network push+run via $etherload -r"
    "$etherload" -r "$prg"
    ;;
  *)
    usage
    ;;
esac
