#!/usr/bin/env bash
# themes/build-ruby.md の Ubuntu/Debian 向け apt-get リストを冪等に流すための薄いラッパ。
# - 既に入っているパッケージは skip する(差分だけを apt に渡す)
# - 依存に挙がっている名前をそのまま使う(互換や別名にフォールバックしない)

set -euo pipefail

PACKAGES=(
  build-essential
  autoconf
  bison
  libssl-dev
  libreadline-dev
  zlib1g-dev
  libyaml-dev
  libffi-dev
  libgmp-dev
  rustc
)

missing=()
for pkg in "${PACKAGES[@]}"; do
  if dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
    printf '  OK  %s\n' "$pkg"
  else
    printf '  --  %s (missing)\n' "$pkg"
    missing+=("$pkg")
  fi
done

if [[ ${#missing[@]} -eq 0 ]]; then
  echo "all dependencies already installed"
  exit 0
fi

echo
echo "installing: ${missing[*]}"
sudo apt-get update
sudo apt-get install -y "${missing[@]}"

echo
echo "post-install versions:"
for cmd in autoconf bison rustc; do
  if command -v "$cmd" >/dev/null; then
    printf '  %-8s %s\n' "$cmd" "$("$cmd" --version | head -n1)"
  fi
done
