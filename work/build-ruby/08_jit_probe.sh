#!/usr/bin/env bash
# interpreter / --yjit / --zjit の 3 モードで fib(35) を回し、
# JIT が実際にコード生成まで走って stats に数字が入ることを確認する。
# --yjit-stats の出力は長大なので、grep は失敗許容(|| true)でフィルタだけ。

set -eu  # -o pipefail は外して、grep no-match で止まらないように
PREFIX="${PREFIX:-$HOME/.local/share/mise/installs/ruby/master}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/08_jit_probe.rb"
LOG="$HERE/logs"
mkdir -p "$LOG"

echo "[interpreter]"
"$PREFIX/bin/ruby" "$SCRIPT"

echo
echo "[--yjit --yjit-stats]"
"$PREFIX/bin/ruby" --yjit --yjit-stats "$SCRIPT" > "$LOG/jit_probe.yjit.log" 2>&1 || true
# スクリプト自身の出力(YJIT fib ... と compiled_*)だけ拾う。
grep -E '^(YJIT\b|  (compiled|yjit_insns|side_exit))' "$LOG/jit_probe.yjit.log" || true

echo
echo "[--zjit --zjit-stats-quiet]"
"$PREFIX/bin/ruby" --zjit --zjit-stats-quiet "$SCRIPT" > "$LOG/jit_probe.zjit.log" 2>&1 || true
cat "$LOG/jit_probe.zjit.log"
