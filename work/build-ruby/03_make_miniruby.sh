#!/usr/bin/env bash
# miniruby だけ先に作る。miniruby はソースから最初に立ち上がる「ブートストラップ用 ruby」で、
# 以降のフルビルドはこの miniruby が自分自身のパーサや require を動かしながら組み上げていく。
# どのくらいの時間で miniruby が立ち上がるか、そして miniruby には何が欠けているかを見る。

set -euo pipefail

RUBY_SRC="${RUBY_SRC:-$HOME/repos/ruby}"
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logs"
mkdir -p "$LOG_DIR"

cd "$RUBY_SRC"

JOBS="$(nproc)"
echo "[make miniruby -j$JOBS]"
time make -j"$JOBS" miniruby 2>&1 | tee "$LOG_DIR/make_miniruby.log" | tail -5

echo
echo "[miniruby info]"
./miniruby --version
printf 'size: %s\n' "$(stat -c %s miniruby) bytes"
printf 'deps: %s\n' "$(ldd miniruby | wc -l) libraries"
