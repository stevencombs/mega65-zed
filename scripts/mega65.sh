#!/usr/bin/env bash
# Tokenize, run, and push a Commodore BASIC listing from any directory.
#
#   .bas       BASIC 2.0   petcat -w2   load $0801 (VIC-20 task uses $1001)
#   .b65 .m65  BASIC65     petcat -w65  load $2001
#
# .m65 is the older MEGA65 suffix. It is the same dialect as .b65.
# A running emulator is left alone unless CBM_RESTART_EMULATOR=1.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cbm-tools.sh
source "$HERE/cbm-tools.sh"

usage() {
  cat >&2 <<EOF
usage: $(basename "$0") <command> <listing.bas|.b65|.m65>

  check       tokenize only
  tokenize    tokenize and print the PRG path
  run         .b65/.m65 in XEMU, .bas in VICE x64sc
  run-xemu    XEMU (BASIC65 files only)
  push-xemu   same as run-xemu
  run-c64     VICE x64sc (.bas)
  run-vic20   VICE xvic (.bas, load \$1001 unless CBM_VIC_LOAD is set)
  push        etherload (load, do not RUN)
  push-run    etherload -r

Env: PETCAT, ETHERLOAD, XMEGA65, XMEGA65_APP, X64SC, XVIC,
     CBM_BIN_DIR, M65TOOLS, CBM_RESTART_EMULATOR, CBM_EMULATOR_DRY_RUN,
     CBM_BASIC2_LOAD, CBM_MEGA65_LOAD, CBM_VIC_LOAD, CBM_FORCE_MODE,
     CBM_FORCE_LOAD, CBM_PETCAT_MODE, CBM_XMEGA65_ARGS, CBM_X64SC_ARGS,
     CBM_XVIC_ARGS.
EOF
  exit 2
}

ext_of() {
  local base
  base="$(basename "$1")"
  printf '%s' "${base##*.}" | tr '[:upper:]' '[:lower:]'
}

stem_of() {
  local base
  base="$(basename "$1")"
  printf '%s' "${base%.*}"
}

program_dir() {
  local f="${1:-}" d
  if [[ -z "$f" || "$f" == *'$ZED_FILE'* ]]; then
    echo "Open a .bas, .b65, or .m65 listing first." >&2
    exit 1
  fi
  [[ "$f" == /* ]] || f="$PWD/$f"
  d="$(cd "$(dirname "$f")" && pwd)"
  if [[ "$(basename "$d")" == "src" ]]; then
    dirname "$d"
    return
  fi
  printf '%s\n' "$d"
}

find_source() {
  local dir="$1" stem="$2" ext hit
  for ext in bas b65 m65; do
    if [[ -f "$dir/src/${stem}.${ext}" ]]; then
      printf '%s\n' "$dir/src/${stem}.${ext}"
      return 0
    fi
    if [[ -f "$dir/${stem}.${ext}" ]]; then
      printf '%s\n' "$dir/${stem}.${ext}"
      return 0
    fi
  done
  hit="$(ls "$dir"/src/*.bas "$dir"/src/*.b65 "$dir"/src/*.m65 \
    "$dir"/*.bas "$dir"/*.b65 "$dir"/*.m65 2>/dev/null | head -n 1 || true)"
  if [[ -z "$hit" ]]; then
    echo "No .bas, .b65, or .m65 listing in $dir" >&2
    exit 1
  fi
  printf '%s\n' "$hit"
}

require_ext() {
  local ext="$1" want
  shift
  for want in "$@"; do
    if [[ "$ext" == "$want" ]]; then
      return 0
    fi
  done
  echo "This command accepts $(printf '.%s ' "$@")(got .$ext)." >&2
  exit 1
}

# Prints "mode load" for the listing extension.
dialect_of() {
  local ext="$1" mode load
  case "$ext" in
    bas)
      mode=2
      load="${CBM_BASIC2_LOAD:-0801}"
      ;;
    b65|m65)
      mode=65
      load="${CBM_MEGA65_LOAD:-2001}"
      ;;
    *)
      echo "Need a .bas, .b65, or .m65 listing." >&2
      return 1
      ;;
  esac
  if [[ -n "${CBM_PETCAT_MODE:-}" ]]; then
    mode="$CBM_PETCAT_MODE"
  fi
  if [[ -n "${CBM_FORCE_MODE:-}" ]]; then
    mode="$CBM_FORCE_MODE"
  fi
  if [[ -n "${CBM_FORCE_LOAD:-}" ]]; then
    load="$CBM_FORCE_LOAD"
  fi
  printf '%s %s\n' "$mode" "$load"
}

tokenize() {
  local dir="$1" src="$2" mode="$3" load="$4" stem prg petcat
  stem="$(stem_of "$src")"
  mkdir -p "$dir/export"
  prg="$dir/export/${stem}.prg"
  petcat="$(cbm_find_petcat "$mode")" || {
    echo "petcat not found. Run mega65zed-install.sh or set PETCAT." >&2
    echo "Looked at PETCAT, PATH, ~/.retrocombs-m65/bin, ~/m65tools, and Homebrew." >&2
    return 1
  }
  echo "petcat -w${mode} -l ${load}  ($src) → $prg" >&2
  "$petcat" -w"$mode" -l "$load" -f -o "$prg" -- "$src" </dev/null
  echo "PRG $prg  load \$${load}  $(wc -c <"$prg" | tr -d ' ') bytes" >&2
  cp "$prg" "$dir/build.prg"
  printf '%s\n' "$prg"
}

launch_with_args() {
  local bin="$1"
  shift
  local proc st
  proc="$(basename "$bin")"
  st=0
  cbm_leave_if_running "$proc" || st=$?
  if [[ "$st" -eq 2 ]]; then
    return 2
  fi
  if [[ "$st" -ne 0 ]]; then
    return "$st"
  fi
  if [[ "${CBM_EMULATOR_DRY_RUN:-}" == "1" ]]; then
    echo "dry-run: $bin $*" >&2
    return 0
  fi
  if [[ "$(uname -s)" == "Darwin" && "$bin" == */Contents/MacOS/* ]]; then
    local app
    app="${bin%/Contents/MacOS/*}"
    echo "launch: open -na $app --args $*" >&2
    open -na "$app" --args "$@"
  else
    echo "launch: $bin $*" >&2
    nohup "$bin" "$@" >/tmp/cbm-emulator.log 2>&1 </dev/null &
    disown || true
  fi
  sleep 0.6
  if pgrep -x "$proc" >/dev/null 2>&1; then
    echo "$proc is running (pid $(pgrep -x "$proc" | tr '\n' ' '))" >&2
    return 0
  fi
  echo "$proc failed to start. Log:" >&2
  cat /tmp/cbm-emulator.log >&2 || true
  return 1
}

launch_emulator() {
  local bin="$1"
  shift
  # ${arr[@]+...} is empty-array safe on bash 3.2 with set -u (macOS).
  launch_with_args "$bin" "$@" "${CBM_EXTRA[@]+"${CBM_EXTRA[@]}"}"
}

run_xemu() {
  local prg="$1" bin st
  bin="$(cbm_find_xmega65)" || {
    echo "xmega65 not found. Install XEMU, or set XMEGA65 / XMEGA65_APP." >&2
    return 1
  }
  cbm_append_split "${CBM_XMEGA65_ARGS:-}"
  st=0
  launch_emulator "$bin" -besure -prg "$prg" || st=$?
  if [[ "$st" -eq 2 ]]; then
    echo "XEMU loads a PRG only when it starts, so this listing was not injected." >&2
    return 2
  fi
  return "$st"
}

run_vice() {
  local which="$1" prg="$2" bin args st
  if [[ "$which" == "x64sc" ]]; then
    bin="$(cbm_find_x64sc)" || {
      echo "x64sc not found. Install VICE, or set X64SC." >&2
      return 1
    }
    args="${CBM_X64SC_ARGS:-}"
  else
    bin="$(cbm_find_xvic)" || {
      echo "xvic not found. Install VICE, or set XVIC." >&2
      return 1
    }
    args="${CBM_XVIC_ARGS:-}"
  fi
  cbm_append_split "$args"
  st=0
  launch_emulator "$bin" -autostartprgmode 1 -autostart "$prg" || st=$?
  if [[ "$st" -eq 2 ]]; then
    echo "VICE loads this PRG when it starts, so the running copy was left as it is." >&2
    return 2
  fi
  return "$st"
}

finish_emulator() {
  local st="$1" prg="$2"
  if [[ "$st" -eq 2 ]]; then
    printf '%s\n' "$prg"
    exit 0
  fi
  if [[ "$st" -ne 0 ]]; then
    exit "$st"
  fi
  printf '%s\n' "$prg"
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
ext="$(ext_of "$src")"
case "$ext" in
  bas|b65|m65) ;;
  *)
    echo "Need a .bas, .b65, or .m65 listing (got $src)." >&2
    exit 1
    ;;
esac

case "$cmd" in
  run-vic20)
    require_ext "$ext" bas
    export CBM_FORCE_MODE=2
    if [[ -z "${CBM_FORCE_LOAD:-}" ]]; then
      export CBM_FORCE_LOAD="${CBM_VIC_LOAD:-1001}"
    fi
    ;;
  run-c64)
    require_ext "$ext" bas
    export CBM_FORCE_MODE=2
    ;;
  run|run-xemu|push-xemu)
    if [[ "$cmd" != "run" ]]; then
      require_ext "$ext" b65 m65
    fi
    ;;
  check|tokenize|push|push-run) ;;
  *) usage ;;
esac

mode=""
load=""
read -r mode load < <(dialect_of "$ext")
if [[ -z "$mode" || -z "$load" ]]; then
  echo "Could not decide petcat mode for .$ext" >&2
  exit 1
fi

case "$cmd" in
  check)
    tokenize "$dir" "$src" "$mode" "$load" >/dev/null
    echo "Check OK."
    ;;
  tokenize)
    tokenize "$dir" "$src" "$mode" "$load"
    ;;
  run)
    prg="$(tokenize "$dir" "$src" "$mode" "$load")"
    st=0
    if [[ "$ext" == "bas" ]]; then
      run_vice x64sc "$prg" || st=$?
    else
      run_xemu "$prg" || st=$?
    fi
    finish_emulator "$st" "$prg"
    ;;
  run-xemu|push-xemu)
    prg="$(tokenize "$dir" "$src" "$mode" "$load")"
    st=0
    run_xemu "$prg" || st=$?
    finish_emulator "$st" "$prg"
    ;;
  run-c64)
    prg="$(tokenize "$dir" "$src" "$mode" "$load")"
    st=0
    run_vice x64sc "$prg" || st=$?
    finish_emulator "$st" "$prg"
    ;;
  run-vic20)
    prg="$(tokenize "$dir" "$src" "$mode" "$load")"
    st=0
    run_vice xvic "$prg" || st=$?
    finish_emulator "$st" "$prg"
    ;;
  push|push-run)
    if [[ "$ext" == "bas" ]]; then
      echo "warning: $src is BASIC 2.0 (.bas). Tokenizing with petcat -w${mode}, load \$${load}. MEGA65 BASIC65 listings use .b65/.m65 and load \$2001. Pushing anyway." >&2
    fi
    prg="$(tokenize "$dir" "$src" "$mode" "$load")"
    etherload="$(cbm_find_etherload)" || {
      echo "etherload not found. Set ETHERLOAD, or install mega65-tools into ~/.retrocombs-m65/bin or ~/m65tools." >&2
      exit 1
    }
    if [[ "$cmd" == "push" ]]; then
      echo "Network push via $etherload (load, do not RUN)" >&2
      "$etherload" "$prg"
      echo "On the MEGA65 you should be at READY. Type RUN if you want it to go."
    else
      echo "Network push+run via $etherload -r" >&2
      "$etherload" -r "$prg"
    fi
    printf '%s\n' "$prg"
    ;;
esac
