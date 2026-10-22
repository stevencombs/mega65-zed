#!/usr/bin/env bash
# Offline discovery tests, then a real petcat smoke test for each dialect.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=cbm-tools.sh
source "$ROOT/scripts/cbm-tools.sh"

assert_eq() {
  local got="$1" want="$2" msg="$3"
  if [[ "$got" != "$want" ]]; then
    echo "FAIL $msg" >&2
    echo "  got:  [$got]" >&2
    echo "  want: [$want]" >&2
    exit 1
  fi
  echo "ok $msg"
}

assert_status() {
  local want="$1" msg="$2"
  shift 2
  local st=0
  "$@" >/tmp/cbm-test-out 2>/tmp/cbm-test-err || st=$?
  if [[ "$st" != "$want" ]]; then
    echo "FAIL $msg (status $st, wanted $want)" >&2
    echo "--- stdout ---" >&2
    cat /tmp/cbm-test-out >&2 || true
    echo "--- stderr ---" >&2
    cat /tmp/cbm-test-err >&2 || true
    exit 1
  fi
  echo "ok $msg"
}

bash -n "$ROOT/scripts/cbm-tools.sh"
bash -n "$ROOT/scripts/mega65.sh"
bash -n "$ROOT/scripts/link-m65tools.sh"
bash -n "$ROOT/mega65zed-install.sh"
bash -n "$ROOT/copy-snippets.sh"
echo "ok bash -n"

if grep -R -n -E '/Users/stevencombs|arch -x86_64|file_associations' \
  --exclude=test-tools.sh \
  "$ROOT/scripts" "$ROOT/mega65zed-install.sh" "$ROOT/copy-snippets.sh" \
  "$ROOT/.zed" "$ROOT/languages" "$ROOT/extension.toml"; then
  echo "FAIL hardcoded path or invalid Zed key" >&2
  exit 1
fi
echo "ok no hardcoded home, Rosetta, or file_associations"

assert_eq "$(cbm_petcat_zip_subdir_for Darwin arm64)" "macOS-arm" "apple silicon petcat folder"
assert_eq "$(cbm_petcat_zip_subdir_for Darwin aarch64)" "macOS-arm" "apple silicon aarch64 alias"
assert_eq "$(cbm_petcat_zip_subdir_for Darwin x86_64)" "macOS-intel" "intel mac petcat folder"
assert_eq "$(cbm_petcat_zip_subdir_for Linux x86_64)" "Linux" "linux petcat folder"
st=0
cbm_petcat_zip_subdir_for Linux aarch64 >/dev/null 2>&1 || st=$?
assert_eq "$st" "1" "linux aarch64 has no petcat in the zip"
assert_eq "$(cbm_petcat_zip_subdir)" "$(cbm_petcat_zip_subdir_for "$(uname -s)" "$(uname -m)")" "host petcat folder"

assert_eq "$(cbm_m65tools_build_number "https://example/m65tools-develo-968-44c63d-macos.7z")" "968" "build number 968"
assert_eq "$(cbm_m65tools_build_number "https://example/m65tools-develo-911-old-macos.7z")" "911" "build number 911"

picked="$(printf '%s\n' \
  "https://example/m65tools-develo-911-aaaa-macos.7z" \
  "https://example/m65tools-develo-968-44c63d-macos.7z" \
  "https://example/m65tools-develo-500-bbbb-linux.7z" \
  | cbm_pick_m65tools_url macos)"
assert_eq "$picked" "https://example/m65tools-develo-968-44c63d-macos.7z" "newest macos asset, not the stale first one"
picked="$(printf '%s\n' \
  "https://example/m65tools-develo-911-aaaa-macos.7z" \
  "https://example/m65tools-develo-500-bbbb-linux.7z" \
  | cbm_pick_m65tools_url linux)"
assert_eq "$picked" "https://example/m65tools-develo-500-bbbb-linux.7z" "linux asset"
st=0
printf '' | cbm_pick_m65tools_url macos >/dev/null 2>&1 || st=$?
assert_eq "$st" "1" "no asset is an error"

WORK="$(mktemp -d)"
export HOME="$WORK/home"
export CBM_BIN_DIR="$WORK/bin"
export M65TOOLS="$WORK/m65tools"
mkdir -p "$HOME" "$CBM_BIN_DIR" "$M65TOOLS" "$HOME/m65tools" "$HOME/.local/bin" "$WORK/path"
export PATH="$WORK/path:/usr/bin:/bin"

cat >"$WORK/path/petcat" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == "-k" ]]; then
  echo "Basic v2.0 (C64/VIC20/PET)"
  exit 0
fi
printf '%s\n' "$*" >>"${PETCAT_LOG:?}"
prev=""
for a in "$@"; do
  if [[ "$prev" == "-o" ]]; then
    mkdir -p "$(dirname "$a")"
    printf 'fake' >"$a"
  fi
  prev="$a"
done
exit 0
EOF
chmod +x "$WORK/path/petcat"

cat >"$CBM_BIN_DIR/petcat" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == "-k" ]]; then
  echo "Basic v65.0 (Mega65)"
  exit 0
fi
printf '%s\n' "$*" >>"${PETCAT_LOG:?}"
prev=""
for a in "$@"; do
  if [[ "$prev" == "-o" ]]; then
    mkdir -p "$(dirname "$a")"
    printf 'fake65' >"$a"
  fi
  prev="$a"
done
exit 0
EOF
chmod +x "$CBM_BIN_DIR/petcat"

export PETCAT_LOG="$WORK/petcat.log"
touch "$PETCAT_LOG"

# Mode 65 must skip the PATH petcat (no v65) and use CBM_BIN_DIR.
unset PETCAT || true
got="$(cbm_find_petcat 65)"
assert_eq "$got" "$CBM_BIN_DIR/petcat" "mode 65 skips a PATH petcat without -w65"

# Mode 2 may use the PATH petcat even without -w65.
got="$(cbm_find_petcat 2)"
assert_eq "$got" "$WORK/path/petcat" "mode 2 uses PATH petcat"

# An explicit bad PETCAT is an error, not a silent fallback.
export PETCAT="$WORK/path/petcat"
st=0
cbm_find_petcat 65 >/tmp/cbm-test-out 2>/tmp/cbm-test-err || st=$?
assert_eq "$st" "1" "explicit PETCAT without -w65 fails"
assert_eq "$(cat /tmp/cbm-test-out)" "" "explicit PETCAT does not print another path"
unset PETCAT

# etherload.prg is never chosen. etherload.osx is.
mkdir -p "$WORK/tree/nested"
printf 'prg' >"$WORK/tree/etherload.prg"
chmod +x "$WORK/tree/etherload.prg"
printf 'osx' >"$WORK/tree/nested/etherload.osx"
chmod +x "$WORK/tree/nested/etherload.osx"
st=0
cbm_install_tree_tool "$WORK/tree" "$WORK/onlyprg" etherload || st=$?
assert_eq "$st" "1" "etherload.prg is not installed as etherload"
cbm_install_tree_tool "$WORK/tree" "$WORK/got-ether" etherload etherload.osx
assert_eq "$(cat "$WORK/got-ether")" "osx" "etherload.osx is the fallback name"

# PATH snippet is idempotent and prepends the bin dir.
cbm_ensure_path_snippet "$HOME/.bashrc"
cbm_ensure_path_snippet "$HOME/.bashrc"
count="$(grep -c '>>> retrocombs mega65 >>>' "$HOME/.bashrc")"
assert_eq "$count" "1" "path snippet is written once"
grep -q 'export PATH="$HOME/.retrocombs-m65/bin:$PATH"' "$HOME/.bashrc"
echo "ok path snippet prepends the tools dir"

# Shell rc selection: neither file exists, bash shell creates bashrc.
rm -f "$HOME/.bashrc" "$HOME/.zshrc"
SHELL=/bin/bash cbm_install_path_snippets
[[ -f "$HOME/.bashrc" && ! -f "$HOME/.zshrc" ]]
echo "ok bash gets .bashrc when neither rc exists"
rm -f "$HOME/.bashrc" "$HOME/.zshrc"
SHELL=/bin/zsh cbm_install_path_snippets
[[ -f "$HOME/.zshrc" && ! -f "$HOME/.bashrc" ]]
echo "ok zsh gets .zshrc when neither rc exists"

# copy-snippets does not write plaintext.json, and --remove-stale is picky.
SNIP="$WORK/snippets"
mkdir -p "$SNIP"
printf '{ "plain": true }\n' >"$SNIP/plaintext.json"
printf '{ "old": true }\n' >"$SNIP/snippets.json"
printf 'Clear screen + home  CHR$(147)\n' >"$SNIP/plaintext_old.json"
ZED_SNIPPETS_DIR="$SNIP" "$ROOT/copy-snippets.sh" >/tmp/cbm-copy.out
[[ -f "$SNIP/plaintext.json" && -f "$SNIP/snippets.json" ]]
echo "ok copy-snippets does not delete without --remove-stale"
ZED_SNIPPETS_DIR="$SNIP" "$ROOT/copy-snippets.sh" --remove-stale >/tmp/cbm-copy.out
[[ -f "$SNIP/plaintext.json" ]]
[[ ! -f "$SNIP/snippets.json" ]]
[[ ! -f "$SNIP/plaintext_old.json" ]]
echo "ok --remove-stale keeps a real plaintext.json"
printf '{\n  "clr": { "description": "Clear screen + home  CHR$(147)" }\n}\n' >"$SNIP/plaintext.json"
ZED_SNIPPETS_DIR="$SNIP" "$ROOT/copy-snippets.sh" --remove-stale >/tmp/cbm-copy.out
[[ ! -f "$SNIP/plaintext.json" ]]
echo "ok --remove-stale removes the old PETSCII plaintext.json"

# Script wiring with the fake petcat. Listings live outside the repo.
SRC="$WORK/src"
mkdir -p "$SRC"
printf '10 print "{clr}hi"\n' >"$SRC/hello.bas"
printf '10 graphic 1,1\n' >"$SRC/hello.b65"
cp "$ROOT/color-demo.m65" "$SRC/color-demo.m65"

export PETCAT="$CBM_BIN_DIR/petcat"
: >"$PETCAT_LOG"
prg="$("$ROOT/scripts/mega65.sh" tokenize "$SRC/hello.bas")"
grep -q -- '-w2' "$PETCAT_LOG"
grep -q -- '-l 0801' "$PETCAT_LOG"
assert_eq "$(cat "$prg")" "fake65" "tokenize .bas writes a prg"
echo "ok .bas uses petcat -w2 -l 0801"

: >"$PETCAT_LOG"
"$ROOT/scripts/mega65.sh" tokenize "$SRC/hello.b65" >/dev/null
grep -q -- '-w65' "$PETCAT_LOG"
grep -q -- '-l 2001' "$PETCAT_LOG"
echo "ok .b65 uses petcat -w65 -l 2001"

: >"$PETCAT_LOG"
"$ROOT/scripts/mega65.sh" check "$SRC/color-demo.m65" >/dev/null
grep -q -- '-w65' "$PETCAT_LOG"
grep -q -- '-l 2001' "$PETCAT_LOG"
echo "ok .m65 is a BASIC65 alias"

# Emulators: fakes on PATH. pgrep/pkill record what happened.
cat >"$WORK/path/pgrep" <<'EOF'
#!/bin/bash
if [[ "${CBM_TEST_NO_PROCESS:-}" == "1" ]]; then
  exit 1
fi
if [[ "$1" == "-x" && "$2" == "xmega65" ]]; then
  echo 4242
  exit 0
fi
exit 1
EOF
cat >"$WORK/path/pkill" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${PKILL_LOG:?}"
exit 0
EOF
cat >"$WORK/path/xmega65" <<'EOF'
#!/bin/bash
exit 0
EOF
cat >"$WORK/path/x64sc" <<'EOF'
#!/bin/bash
exit 0
EOF
cat >"$WORK/path/xvic" <<'EOF'
#!/bin/bash
exit 0
EOF
cat >"$WORK/path/etherload" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${ETHER_LOG:?}"
exit 0
EOF
chmod +x "$WORK/path/pgrep" "$WORK/path/pkill" "$WORK/path/xmega65" \
  "$WORK/path/x64sc" "$WORK/path/xvic" "$WORK/path/etherload"

export PKILL_LOG="$WORK/pkill.log"
export ETHER_LOG="$WORK/ether.log"
export XMEGA65="$WORK/path/xmega65"
touch "$PKILL_LOG" "$ETHER_LOG"

: >"$PKILL_LOG"
"$ROOT/scripts/mega65.sh" run-xemu "$SRC/hello.b65" >/tmp/cbm-run.out 2>/tmp/cbm-run.err
[[ ! -s "$PKILL_LOG" ]]
grep -q 'already running' /tmp/cbm-run.err
grep -q 'was not injected' /tmp/cbm-run.err
echo "ok a running XEMU is not killed"

: >"$PKILL_LOG"
CBM_RESTART_EMULATOR=1 CBM_EMULATOR_DRY_RUN=1 \
  "$ROOT/scripts/mega65.sh" run-xemu "$SRC/hello.b65" >/tmp/cbm-run.out 2>/tmp/cbm-run.err
grep -q 'xmega65' "$PKILL_LOG"
grep -q 'dry-run:' /tmp/cbm-run.err
grep -q -- '-besure' /tmp/cbm-run.err
grep -q -- '-prg' /tmp/cbm-run.err
echo "ok CBM_RESTART_EMULATOR=1 stops XEMU and prints the launch"

unset CBM_RESTART_EMULATOR || true
st=0
CBM_EMULATOR_DRY_RUN=1 "$ROOT/scripts/mega65.sh" run-xemu "$SRC/hello.bas" >/tmp/cbm-run.out 2>/tmp/cbm-run.err || st=$?
assert_eq "$st" "1" "run-xemu rejects .bas"
st=0
CBM_TEST_NO_PROCESS=1 CBM_EMULATOR_DRY_RUN=1 \
  "$ROOT/scripts/mega65.sh" run-c64 "$SRC/hello.b65" >/tmp/cbm-run.out 2>/tmp/cbm-run.err || st=$?
assert_eq "$st" "1" "run-c64 rejects .b65"

: >"$PETCAT_LOG"
: >"$PKILL_LOG"
CBM_TEST_NO_PROCESS=1 CBM_EMULATOR_DRY_RUN=1 CBM_XVIC_ARGS="--extra flag" \
  "$ROOT/scripts/mega65.sh" run-vic20 "$SRC/hello.bas" >/tmp/cbm-run.out 2>/tmp/cbm-run.err
grep -q -- '-l 1001' "$PETCAT_LOG"
grep -q 'dry-run:' /tmp/cbm-run.err
grep -q -- '-autostartprgmode 1' /tmp/cbm-run.err
grep -q -- '--extra flag' /tmp/cbm-run.err
[[ ! -s "$PKILL_LOG" ]]
echo "ok VIC-20 tokenize uses load 1001 and does not kill xvic"

: >"$ETHER_LOG"
"$ROOT/scripts/mega65.sh" push "$SRC/hello.bas" >/tmp/cbm-run.out 2>/tmp/cbm-run.err
grep -q 'BASIC 2.0' /tmp/cbm-run.err
grep -q 'hello.prg' "$ETHER_LOG"
echo "ok push of .bas warns and still calls etherload"
"$ROOT/scripts/mega65.sh" push-run "$SRC/hello.b65" >/tmp/cbm-run.out 2>/tmp/cbm-run.err
grep -q -- '-r' "$ETHER_LOG"
echo "ok push-run passes -r"

# Real petcat bytes. Prefer a cached zip, else download the pinned one.
ZIP="$WORK/petcat.zip"
if [[ ! -f /tmp/petcat-20230619.zip ]]; then
  curl -fL --max-time 180 -o /tmp/petcat-20230619.zip \
    "https://files.mega65.org/files/p/petcat-20230619_6Veruh.zip"
fi
cp /tmp/petcat-20230619.zip "$ZIP"
cbm_install_petcat_from_zip "$ZIP" "$WORK/real-petcat"
export PETCAT="$WORK/real-petcat"
REAL="$WORK/real"
mkdir -p "$REAL"
printf '10 print "{clr}hi"\n' >"$REAL/hi.bas"
printf '10 graphic 1,1\n' >"$REAL/gfx.bas"
printf '10 graphic 1,1\n' >"$REAL/gfx.b65"
cp "$ROOT/color-demo.m65" "$REAL/color-demo.m65"
cp "$ROOT/examples/basic2.bas" "$REAL/basic2.bas"
cp "$ROOT/examples/basic65.b65" "$REAL/basic65.b65"

"$ROOT/scripts/mega65.sh" check "$REAL/basic2.bas" >/dev/null
"$ROOT/scripts/mega65.sh" check "$REAL/basic65.b65" >/dev/null
"$ROOT/scripts/mega65.sh" tokenize "$REAL/hi.bas" >/dev/null
python3 - "$REAL/export/hi.prg" <<'PY'
import sys
b = open(sys.argv[1], "rb").read()
assert b[:2] == b"\x01\x08", b[:4].hex()
print("ok real petcat -w2 load 0801", b[:2].hex())
PY

CBM_FORCE_MODE=2 CBM_FORCE_LOAD=1001 "$ROOT/scripts/mega65.sh" tokenize "$REAL/hi.bas" >/dev/null
python3 - "$REAL/export/hi.prg" <<'PY'
import sys
b = open(sys.argv[1], "rb").read()
assert b[:2] == b"\x01\x10", b[:4].hex()
print("ok real petcat -w2 load 1001", b[:2].hex())
PY

"$ROOT/scripts/mega65.sh" tokenize "$REAL/gfx.bas" >/dev/null
python3 - "$REAL/export/gfx.prg" <<'PY'
import sys
b = open(sys.argv[1], "rb").read()
assert b[:2] == b"\x01\x08", b[:4].hex()
assert b"GRAPHIC" in b, b.hex()
assert 0xDE not in b
print("ok .bas leaves GRAPHIC as text")
PY

"$ROOT/scripts/mega65.sh" tokenize "$REAL/gfx.b65" >/dev/null
python3 - "$REAL/export/gfx.prg" <<'PY'
import sys
b = open(sys.argv[1], "rb").read()
assert b[:2] == b"\x01\x20", b[:4].hex()
assert 0xDE in b, b.hex()
assert b"GRAPHIC" not in b
print("ok .b65 tokenizes GRAPHIC as 0xDE")
PY

"$ROOT/scripts/mega65.sh" tokenize "$REAL/color-demo.m65" >/dev/null
python3 - "$REAL/export/color-demo.prg" "$REAL/export/basic2.prg" "$REAL/export/basic65.prg" <<'PY'
import sys
demo = open(sys.argv[1], "rb").read()
basic2 = open(sys.argv[2], "rb").read()
basic65 = open(sys.argv[3], "rb").read()
assert demo[:2] == b"\x01\x20", demo[:4].hex()
assert 0x8F in demo[:16], demo[:16].hex()
assert basic2[:2] == b"\x01\x08", basic2[:4].hex()
assert basic65[:2] == b"\x01\x20", basic65[:4].hex()
print("ok color-demo.m65", len(demo), "bytes", demo[:2].hex())
print("ok examples basic2", basic2[:2].hex(), "basic65", basic65[:2].hex())
PY

python3 - "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
text = (root / "extension.toml").read_text()
for needle in (
    'id = "mega65"',
    'name = "Commodore BASIC"',
    'version = "0.7.0"',
    'schema_version = 1',
    'rev = "c57eff3f04c49ac63cdc68e7ae7a3dbe45637a0b"',
    'path = "grammars/tree-sitter-commodore-basic"',
    'snippets/commodore basic.json',
    'snippets/basic65.json',
):
    if needle not in text:
        raise SystemExit(f"extension.toml missing {needle}")
if "plaintext.json" in text or "snippets.json" in text.split("snippets =", 1)[-1]:
    raise SystemExit("extension.toml still ships a global snippet file")

try:
    import tomllib
except ModuleNotFoundError:
    tomllib = None
if tomllib is not None:
    manifest = tomllib.loads(text)
    grammar = manifest["grammars"]["commodore_basic"]
    assert grammar["rev"] == "c57eff3f04c49ac63cdc68e7ae7a3dbe45637a0b"
    assert grammar["path"] == "grammars/tree-sitter-commodore-basic"
    for cfg in ("languages/commodore-basic/config.toml", "languages/basic65/config.toml"):
        lang = tomllib.loads((root / cfg).read_text())
        assert lang["grammar"] == "commodore_basic"
    assert tomllib.loads((root / "languages/commodore-basic/config.toml").read_text())["name"] == "Commodore BASIC"
    assert tomllib.loads((root / "languages/basic65/config.toml").read_text())["path_suffixes"] == ["b65", "m65"]

def prefixes(path):
    data = json.loads(path.read_text())
    seen = []
    for entry in data.values():
        prefs = entry["prefix"]
        if isinstance(prefs, str):
            prefs = [prefs]
        for pref in prefs:
            if pref in seen:
                raise SystemExit(f"duplicate prefix {pref} in {path.name}")
            seen.append(pref)
    return data, seen

basic, basic_prefs = prefixes(root / "snippets" / "basic65.json")
cbm, cbm_prefs = prefixes(root / "snippets" / "commodore basic.json")
assert len(basic) == 39, len(basic)
assert "10print" in basic_prefs and "graphic" in basic_prefs
assert "lower" in basic_prefs and "upper" in basic_prefs
assert "hello" not in basic
assert "graphic" not in cbm and "basic10" not in cbm
assert "lower" in cbm_prefs and "upper" in cbm_prefs
assert "hello" in cbm_prefs and "c64hello" in cbm_prefs
assert "vichello" in cbm_prefs and "vic20hello" in cbm_prefs
for banned in ("snippets.json", "plaintext.json", "cbm basic.json", "mega65 basic.json"):
    if (root / "snippets" / banned).exists():
        raise SystemExit(f"stale snippet still shipped: {banned}")
if (root / "themes" / "mega65.json").exists():
    raise SystemExit("duplicate theme file themes/mega65.json")
print("ok manifest and snippets")
PY

INST_HOME="$WORK/install-home"
mkdir -p "$INST_HOME"
env -u CBM_BIN_DIR -u M65TOOLS -u PETCAT -u XMEGA65 -u ETHERLOAD \
  HOME="$INST_HOME" SHELL=/bin/bash \
  "$ROOT/mega65zed-install.sh"
[[ -x "$INST_HOME/.retrocombs-m65/bin/petcat" ]]
[[ -x "$INST_HOME/.retrocombs-m65/bin/mega65.sh" ]]
[[ -x "$INST_HOME/.retrocombs-m65/bin/cbm-tools.sh" ]]
grep -q 'retrocombs mega65' "$INST_HOME/.bashrc"
"$INST_HOME/.retrocombs-m65/bin/petcat" -k </dev/null | grep -qi 'v65'
echo "ok installer (temp HOME) put petcat and the scripts on bashrc"

echo "all tool tests ok"
