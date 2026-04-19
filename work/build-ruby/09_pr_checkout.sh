#!/usr/bin/env bash
# 小さな open PR を `gh pr checkout` で持ってきて、差分ビルド → テスト実行まで
# 通すフロー。合宿でトーク登壇者の PR をローカルで試すときの最短経路。
# 対象: #16770 (+26/-0, test/ruby/test_string.rb だけ変わる test-only PR)。
# 戻るのは `git checkout master` で十分(切ったローカルブランチは残るがそのまま)。

set -euo pipefail

RUBY_SRC="${RUBY_SRC:-$HOME/repos/ruby}"
PR="${PR:-16770}"

cd "$RUBY_SRC"

echo "[state: before]"
printf '  branch %s\n' "$(git rev-parse --abbrev-ref HEAD)"

echo
echo "[gh pr checkout $PR]"
gh pr checkout "$PR"
printf '  branch %s\n' "$(git rev-parse --abbrev-ref HEAD)"
printf '  HEAD   %s %s\n' "$(git rev-parse --short HEAD)" "$(git log -1 --format=%s)"

echo
echo "[incremental make]"
time make -j"$(nproc)" 2>&1 | tail -3

echo
echo "[run only the new test methods]"
./ruby test/runner.rb test/ruby/test_string.rb -n "/test_(get|set)byte/" 2>&1 | tail -10

echo
echo "[back to master]"
git checkout master
printf '  branch %s\n' "$(git rev-parse --abbrev-ref HEAD)"
