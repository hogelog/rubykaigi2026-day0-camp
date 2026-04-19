#!/usr/bin/env bash
# PREFIX=$HOME/.local/share/mise/installs/ruby/master に install した master ruby を
# mise から「master」として見えるか確認する。mise activate を前提にしない経路で動くかを見る。

set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local/share/mise/installs/ruby/master}"

echo "[mise list ruby]"
mise list ruby 2>&1 || true

echo
echo "[mise exec ruby@master -- ruby --version]"
# exec 経路なら mise activate 不要で、PREFIX/bin を拾ってそのまま動く。
mise exec ruby@master -- ruby --version
mise exec ruby@master -- gem --version
mise exec ruby@master -- which ruby

echo
echo "[mise.toml でプロジェクト切替のシミュレーション]"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/mise.toml" <<EOF
[tools]
ruby = "master"
EOF
mise trust "$tmp/mise.toml" >/dev/null
(cd "$tmp" && mise exec -- ruby --version)
