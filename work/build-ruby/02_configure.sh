#!/usr/bin/env bash
# autogen.sh → configure を実行し、summary と時間を記録する。
# PREFIX は mise の installs 配下に切る(ガイド推奨)。build ディレクトリは src 直下。
# ログは work/build-ruby/logs/ に残すが .gitignore で除外するので、必要箇所は NOTES に転記する。

set -euo pipefail

RUBY_SRC="${RUBY_SRC:-$HOME/repos/ruby}"
PREFIX="${PREFIX:-$HOME/.local/share/mise/installs/ruby/master}"
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logs"
mkdir -p "$LOG_DIR"

cd "$RUBY_SRC"

echo "[autogen.sh]"
time ./autogen.sh 2>&1 | tee "$LOG_DIR/autogen.log" | tail -5

echo
echo "[configure] PREFIX=$PREFIX"
time ./configure \
  --prefix="$PREFIX" \
  --disable-install-doc \
  2>&1 | tee "$LOG_DIR/configure.log" | tail -40
