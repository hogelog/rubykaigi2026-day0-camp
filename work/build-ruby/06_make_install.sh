#!/usr/bin/env bash
# ビルドツリーの ./ruby は $LOAD_PATH が install prefix を指しているので、
# make install を走らせるまで本来の ruby として使えない(RubyGems も stdlib も読めない)。
# PREFIX 配下にインストールして、その下で再度プローブを流す。

set -euo pipefail

RUBY_SRC="${RUBY_SRC:-$HOME/repos/ruby}"
PREFIX="${PREFIX:-$HOME/.local/share/mise/installs/ruby/master}"
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logs"
mkdir -p "$LOG_DIR"

cd "$RUBY_SRC"

JOBS="$(nproc)"
echo "[make install -j$JOBS]"
time make -j"$JOBS" install 2>&1 | tee "$LOG_DIR/make_install.log" | tail -5

echo
echo "[installed tree: $PREFIX]"
printf 'bin:    %s files\n' "$(find "$PREFIX/bin" -maxdepth 1 -type f 2>/dev/null | wc -l)"
printf 'lib/ruby: %s *.rb\n' "$(find "$PREFIX/lib/ruby" -name '*.rb' 2>/dev/null | wc -l)"
printf 'lib/ruby: %s *.so\n' "$(find "$PREFIX/lib/ruby" -name '*.so' 2>/dev/null | wc -l)"
printf 'gems:   %s\n' "$(ls -1 "$PREFIX"/lib/ruby/gems/*/gems 2>/dev/null | wc -l)"
printf 'du -sh: %s\n' "$(du -sh "$PREFIX" 2>/dev/null | awk '{print $1}')"

echo
echo "[ruby --version from prefix]"
"$PREFIX/bin/ruby" --version
