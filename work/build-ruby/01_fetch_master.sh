#!/usr/bin/env bash
# ~/repos/ruby を origin/master に追随させ、ビルド前に HEAD と API バージョンを記録する。
# ローカル編集は壊したくないので fast-forward のみ。failed = 何か手を入れている合図なので調査する。

set -euo pipefail

RUBY_SRC="${RUBY_SRC:-$HOME/repos/ruby}"
cd "$RUBY_SRC"

echo "[before]"
printf '  HEAD   %s\n' "$(git rev-parse HEAD)"
printf '  branch %s\n' "$(git rev-parse --abbrev-ref HEAD)"
printf '  behind %s commits\n' "$(git rev-list --count HEAD..origin/master 2>/dev/null || echo '?')"

git fetch --tags origin
git checkout master
git pull --ff-only origin master

echo
echo "[after]"
printf '  HEAD         %s\n' "$(git rev-parse HEAD)"
printf '  HEAD date    %s\n' "$(git log -1 --format=%ai HEAD)"
printf '  API version  %s.%s\n' \
  "$(grep -oE 'RUBY_API_VERSION_MAJOR [0-9]+' include/ruby/version.h | awk '{print $2}')" \
  "$(grep -oE 'RUBY_API_VERSION_MINOR [0-9]+' include/ruby/version.h | awk '{print $2}')"
printf '  total commits (master) %s\n' "$(git rev-list --count master)"
