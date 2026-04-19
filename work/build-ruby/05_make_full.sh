#!/usr/bin/env bash
# miniruby の後段。拡張 (enc/*, ext/*) と stdlib を組み、最終的な ruby バイナリを作る。
# 03_make_miniruby.sh の後に実行する前提(miniruby の成果物はそのまま使い回す)。

set -euo pipefail

RUBY_SRC="${RUBY_SRC:-$HOME/repos/ruby}"
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logs"
mkdir -p "$LOG_DIR"

cd "$RUBY_SRC"

JOBS="$(nproc)"
echo "[make -j$JOBS]"
time make -j"$JOBS" 2>&1 | tee "$LOG_DIR/make_full.log" | tail -10

echo
echo "[ruby info]"
./ruby --version
printf 'size:  %s bytes\n' "$(stat -c %s ruby)"
printf 'deps:  %s libraries\n' "$(ldd ruby | wc -l)"
printf 'enc:   %s *.so\n' "$(find .ext -name '*.so' -path '*/enc/*' 2>/dev/null | wc -l)"
printf 'ext:   %s *.so (total)\n' "$(find .ext -name '*.so' 2>/dev/null | wc -l)"
