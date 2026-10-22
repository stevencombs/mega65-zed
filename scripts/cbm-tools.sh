#!/usr/bin/env bash
# Shared tool discovery for scripts/mega65.sh and mega65zed-install.sh.
# Bash 3.2 compatible. Source this file; running it does nothing.
#
# Search order for every tool:
#   1. An explicit env var, if set (PETCAT, ETHERLOAD, XMEGA65, ...)
#   2. PATH
#   3. Known locations: $CBM_BIN_DIR or ~/.retrocombs-m65/bin,
#      $M65TOOLS, ~/m65tools, ~/m65tools/bin, ~/.local/bin,
#      $(brew --prefix)/bin, /opt/homebrew/bin, /usr/local/bin, /usr/bin
#
# If the env var is set but the file is missing or (for BASIC65) the
# petcat binary has no -w65, this fails instead of quietly picking another.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/cbm-tools.sh; it is a library." >&2
  exit 1
fi

cbm_is_exec() {
  [[ -n "${1:-}" && -x "$1" && ! -d "$1" ]]
}

cbm_known_dirs() {
  echo "${CBM_BIN_DIR:-$HOME/.retrocombs-m65/bin}"
  if [[ -n "${M65TOOLS:-}" ]]; then
    echo "$M65TOOLS"
    echo "$M65TOOLS/bin"
  fi
  echo "$HOME/m65tools"
  echo "$HOME/m65tools/bin"
  echo "$HOME/.local/bin"
  if command -v brew >/dev/null 2>&1; then
    local prefix
    prefix="$(brew --prefix 2>/dev/null || true)"
    if [[ -n "$prefix" ]]; then
      echo "$prefix/bin"
    fi
  fi
  echo "/opt/homebrew/bin"
  echo "/usr/local/bin"
  echo "/usr/bin"
}

# First executable named $1 on PATH, then in known dirs.
cbm_search_named() {
  local name="$1" hit dir
  hit="$(command -v "$name" 2>/dev/null || true)"
  if cbm_is_exec "$hit"; then
    printf '%s\n' "$hit"
    return 0
  fi
  while IFS= read -r dir; do
    [[ -n "$dir" ]] || continue
    if cbm_is_exec "$dir/$name"; then
      printf '%s\n' "$dir/$name"
      return 0
    fi
  done <<EOF
$(cbm_known_dirs)
EOF
  return 1
}

cbm_petcat_has_w65() {
  local bin="$1" out
  cbm_is_exec "$bin" || return 1
  out="$("$bin" -k </dev/null 2>&1 || true)"
  printf '%s\n' "$out" | grep -qiE 'v65|mega65|basic65'
}

# $1 is 2 or 65. Mode 65 skips binaries whose -k listing has no BASIC65.
cbm_search_petcat() {
  local mode="$1" hit dir
  hit="$(command -v petcat 2>/dev/null || true)"
  if cbm_is_exec "$hit"; then
    if [[ "$mode" != "65" ]] || cbm_petcat_has_w65 "$hit"; then
      printf '%s\n' "$hit"
      return 0
    fi
  fi
  while IFS= read -r dir; do
    [[ -n "$dir" ]] || continue
    if cbm_is_exec "$dir/petcat"; then
      if [[ "$mode" != "65" ]] || cbm_petcat_has_w65 "$dir/petcat"; then
        printf '%s\n' "$dir/petcat"
        return 0
      fi
    fi
  done <<EOF
$(cbm_known_dirs)
EOF
  return 1
}

cbm_find_petcat() {
  local mode="${1:-2}"
  if [[ -n "${PETCAT:-}" ]]; then
    if ! cbm_is_exec "$PETCAT"; then
      echo "PETCAT is set to '$PETCAT' but it is not executable." >&2
      return 1
    fi
    if [[ "$mode" == "65" ]] && ! cbm_petcat_has_w65 "$PETCAT"; then
      echo "PETCAT is set to '$PETCAT' but it does not list BASIC65 (-w65). Not using a different petcat." >&2
      return 1
    fi
    printf '%s\n' "$PETCAT"
    return 0
  fi
  cbm_search_petcat "$mode"
}

# $1 env var name, remaining args are file names in preference order.
# Never pass a name ending in .prg.
cbm_find_bin() {
  local envname="$1" val="" name hit
  shift
  case "$envname" in
    ETHERLOAD) val="${ETHERLOAD:-}" ;;
    M65) val="${M65:-}" ;;
    MEGA65_FTP) val="${MEGA65_FTP:-}" ;;
    X64SC) val="${X64SC:-}" ;;
    XVIC) val="${XVIC:-}" ;;
    XMEGA65) val="${XMEGA65:-}" ;;
    *)
      echo "unknown tool env $envname" >&2
      return 1
      ;;
  esac
  if [[ -n "$val" ]]; then
    if cbm_is_exec "$val"; then
      printf '%s\n' "$val"
      return 0
    fi
    echo "$envname is set to '$val' but it is not executable." >&2
    return 1
  fi
  for name in "$@"; do
    case "$name" in
      *.prg|*.PRG) continue ;;
    esac
    if hit="$(cbm_search_named "$name")"; then
      printf '%s\n' "$hit"
      return 0
    fi
  done
  return 1
}

cbm_find_etherload() { cbm_find_bin ETHERLOAD etherload etherload.osx; }
cbm_find_m65() { cbm_find_bin M65 m65 m65.osx; }
cbm_find_mega65_ftp() { cbm_find_bin MEGA65_FTP mega65_ftp mega65_ftp.osx; }
cbm_find_x64sc() { cbm_find_bin X64SC x64sc; }
cbm_find_xvic() { cbm_find_bin XVIC xvic; }

cbm_find_xmega65() {
  local app bin
  if [[ -n "${XMEGA65:-}" ]]; then
    if cbm_is_exec "$XMEGA65"; then
      printf '%s\n' "$XMEGA65"
      return 0
    fi
    echo "XMEGA65 is set to '$XMEGA65' but it is not executable." >&2
    return 1
  fi
  if [[ -n "${XMEGA65_APP:-}" ]]; then
    if cbm_is_exec "$XMEGA65_APP/Contents/MacOS/xmega65"; then
      printf '%s\n' "$XMEGA65_APP/Contents/MacOS/xmega65"
      return 0
    fi
    if cbm_is_exec "$XMEGA65_APP"; then
      printf '%s\n' "$XMEGA65_APP"
      return 0
    fi
    echo "XMEGA65_APP is set to '$XMEGA65_APP' but no executable xmega65 was found there." >&2
    return 1
  fi
  for app in "/Applications/xmega65.app" "$HOME/Applications/xmega65.app"; do
    bin="$app/Contents/MacOS/xmega65"
    if cbm_is_exec "$bin"; then
      printf '%s\n' "$bin"
      return 0
    fi
  done
  cbm_find_bin XMEGA65 xmega65
}

# Return 0 if nothing named $1 is running, or it was stopped because
# CBM_RESTART_EMULATOR=1. Return 2 to leave a running emulator alone.
cbm_leave_if_running() {
  local proc="$1"
  if ! pgrep -x "$proc" >/dev/null 2>&1; then
    return 0
  fi
  if [[ "${CBM_RESTART_EMULATOR:-}" == "1" ]]; then
    echo "Restarting $proc because CBM_RESTART_EMULATOR=1." >&2
    pkill -x "$proc" >/dev/null 2>&1 || true
    sleep 0.4
    return 0
  fi
  echo "$proc is already running (pid $(pgrep -x "$proc" | tr '\n' ' ')). Leaving it. Set CBM_RESTART_EMULATOR=1 to restart it with this PRG." >&2
  return 2
}

# Split $1 on whitespace into the global array CBM_EXTRA. Empty is safe.
cbm_append_split() {
  CBM_EXTRA=()
  local raw="${1:-}"
  if [[ -z "$raw" ]]; then
    return 0
  fi
  # Intentional word split so CBM_X64SC_ARGS="--foo bar" stays two args.
  # shellcheck disable=SC2206
  CBM_EXTRA=($raw)
}

cbm_petcat_zip_subdir_for() {
  local os="$1" arch="$2"
  case "$os" in
    Darwin)
      case "$arch" in
        arm64|aarch64) printf '%s\n' "macOS-arm" ;;
        x86_64) printf '%s\n' "macOS-intel" ;;
        *) return 1 ;;
      esac
      ;;
    Linux)
      case "$arch" in
        x86_64|amd64) printf '%s\n' "Linux" ;;
        *) return 1 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

cbm_petcat_zip_subdir() {
  cbm_petcat_zip_subdir_for "$(uname -s)" "$(uname -m)"
}

cbm_host_os_tag() {
  case "$(uname -s)" in
    Darwin) printf '%s\n' "macos" ;;
    Linux) printf '%s\n' "linux" ;;
    *) return 1 ;;
  esac
}

cbm_m65tools_build_number() {
  printf '%s\n' "$1" | sed -n 's/.*m65tools-[A-Za-z][A-Za-z]*-\([0-9][0-9]*\).*/\1/p' | head -n 1
}

cbm_url_matches_os() {
  local url="$1" os="$2" low
  low="$(printf '%s' "$url" | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    macos)
      case "$low" in
        *linux*) return 1 ;;
      esac
      case "$low" in
        *macos*|*darwin*|*osx*) return 0 ;;
      esac
      ;;
    linux)
      case "$low" in
        *macos*|*darwin*|*osx*) return 1 ;;
      esac
      case "$low" in
        *linux*) return 0 ;;
      esac
      ;;
  esac
  return 1
}

# Read download URLs on stdin. Print the highest m65tools build for $1 (macos|linux).
cbm_pick_m65tools_url() {
  local os="$1" url n best="" best_n=-1
  while IFS= read -r url || [[ -n "$url" ]]; do
    [[ -n "$url" ]] || continue
    cbm_url_matches_os "$url" "$os" || continue
    n="$(cbm_m65tools_build_number "$url")"
    [[ -n "$n" ]] || n=0
    if [[ "$best_n" -lt 0 || "$n" -gt "$best_n" ]]; then
      best="$url"
      best_n="$n"
    fi
  done
  if [[ -z "$best" ]]; then
    return 1
  fi
  printf '%s\n' "$best"
}

cbm_github_m65tools_urls() {
  local body
  body="$(curl -fsSL --max-time 60 \
    -H "User-Agent: mega65-zed" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/MEGA65/mega65-tools/releases?per_page=5" 2>/dev/null || true)"
  printf '%s\n' "$body" | grep -o 'https://[^"[:space:]]*m65tools[^"[:space:]]*' || true
}

cbm_seven_zip() {
  if command -v 7zz >/dev/null 2>&1; then
    command -v 7zz
    return 0
  fi
  if command -v 7z >/dev/null 2>&1; then
    command -v 7z
    return 0
  fi
  echo "7z/7zz is not installed. Install p7zip or sevenzip and re-run. This installer does not install Homebrew." >&2
  return 1
}

cbm_unquarantine() {
  local file="$1"
  [[ "$(uname -s)" == "Darwin" ]] || return 0
  if command -v xattr >/dev/null 2>&1; then
    xattr -d com.apple.quarantine "$file" 2>/dev/null || true
  fi
  if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$file" 2>/dev/null || true
  fi
}

# Copy the first exact basename match. Skips *.prg (a BASIC program, not a tool).
cbm_install_tree_tool() {
  local root="$1" dest="$2" name found
  shift 2
  for name in "$@"; do
    case "$name" in
      *.prg|*.PRG) continue ;;
    esac
    found="$(find "$root" -type f -name "$name" ! -name '*.prg' ! -name '*.PRG' | sort | head -n 1 || true)"
    if [[ -n "$found" ]]; then
      cp "$found" "$dest"
      chmod +x "$dest"
      cbm_unquarantine "$dest"
      return 0
    fi
  done
  return 1
}

cbm_install_petcat_from_zip() {
  local zip="$1" dest="$2" subdir tmp src
  subdir="$(cbm_petcat_zip_subdir)" || {
    echo "The MEGA65 petcat zip has no binary for $(uname -s) $(uname -m)." >&2
    echo "Linux aarch64 is not in petcat-20230619. Install petcat yourself and set PETCAT." >&2
    return 1
  }
  if ! command -v unzip >/dev/null 2>&1; then
    echo "unzip is required to unpack petcat." >&2
    return 1
  fi
  tmp="$(mktemp -d)"
  unzip -q "$zip" -d "$tmp"
  src="$(find "$tmp" -type f -path "*/${subdir}/petcat" | sort | head -n 1 || true)"
  if [[ -z "$src" ]]; then
    echo "petcat zip has no ${subdir}/petcat." >&2
    rm -rf "$tmp"
    return 1
  fi
  cp "$src" "$dest"
  chmod +x "$dest"
  cbm_unquarantine "$dest"
  rm -rf "$tmp"
}

cbm_extract_archive() {
  local archive="$1" dest="$2" zipper
  mkdir -p "$dest"
  case "$archive" in
    *.zip)
      command -v unzip >/dev/null 2>&1 || { echo "unzip is required." >&2; return 1; }
      unzip -q "$archive" -d "$dest"
      ;;
    *.7z)
      zipper="$(cbm_seven_zip)" || return 1
      "$zipper" x "$archive" -o"$dest" -y >/dev/null
      ;;
    *.tar.gz|*.tgz)
      tar -xzf "$archive" -C "$dest"
      ;;
    *.tar)
      tar -xf "$archive" -C "$dest"
      ;;
    *)
      echo "Do not know how to extract $archive" >&2
      return 1
      ;;
  esac
}

cbm_ensure_path_snippet() {
  local file="$1"
  local begin="# >>> retrocombs mega65 >>>"
  local end="# <<< retrocombs mega65 <<<"
  local tmp
  if [[ -f "$file" ]] && grep -qF "$begin" "$file"; then
    tmp="$(mktemp)"
    awk -v b="$begin" -v e="$end" '
      $0 == b { skip = 1; next }
      $0 == e { skip = 0; next }
      !skip { print }
    ' "$file" >"$tmp"
    {
      cat "$tmp"
      printf '%s\n' "$begin"
      printf '%s\n' 'export PATH="$HOME/.retrocombs-m65/bin:$PATH"'
      printf '%s\n' "$end"
    } >"$file"
    rm -f "$tmp"
    return 0
  fi
  if [[ -f "$file" ]] && grep -qF '.retrocombs-m65/bin' "$file"; then
    echo "PATH already mentions ~/.retrocombs-m65/bin in $file" >&2
    return 0
  fi
  touch "$file"
  {
    echo ""
    printf '%s\n' "$begin"
    printf '%s\n' 'export PATH="$HOME/.retrocombs-m65/bin:$PATH"'
    printf '%s\n' "$end"
  } >>"$file"
}

cbm_install_path_snippets() {
  local any=0
  if [[ -f "$HOME/.zshrc" ]]; then
    cbm_ensure_path_snippet "$HOME/.zshrc"
    any=1
  fi
  if [[ -f "$HOME/.bashrc" ]]; then
    cbm_ensure_path_snippet "$HOME/.bashrc"
    any=1
  fi
  if [[ "$any" == "0" ]]; then
    case "${SHELL:-}" in
      */zsh) cbm_ensure_path_snippet "$HOME/.zshrc" ;;
      *) cbm_ensure_path_snippet "$HOME/.bashrc" ;;
    esac
  fi
}
