# IRB / Reline — Ruby の REPL を分解して遊ぶ

## なぜ触るのか

IRB は毎日使っているのに、その内側を覗いたことがある人は意外と少ない。Reline は readline 互換を目指した Ruby 製のライン入力ライブラリで、IRB の裏で動いている。

最近の IRB はデバッガ統合・シンタックスハイライト・ページャ連携など、ものすごく進化している。RubyKaigi では IRB / Reline のメンテナから毎年のように新機能の話がある領域。

## 触って分かると嬉しいこと

- IRB の Command 機能と、自作コマンドの追加方法
- Reline が提供しているキーバインド・補完 API
- ターミナル制御(エスケープシーケンス・window size)の基本
- `.irbrc` でできることの広さ

## 取り組みアイデア(難易度順)

### 入門

- `.irbrc` で自分専用エイリアス・ヘルパを整える
- `IRB.conf` を眺めて、プロンプト・履歴・カラーリングを変える
- `irb --help` と `help` コマンドで組み込みコマンドを一周する

### 中級

- IRB の拡張コマンドを自作する(`IRB::ExtendCommand` を継承 / 新しい Command API を使う)
  - 例: 「現在のオブジェクトのメソッド一覧を見やすく出す」「直前の例外を `binding.irb` 相当に落とす」
- Reline の API を使って簡単な REPL ライクな CLI を書いてみる(履歴・補完・マルチライン)
- `binding.irb` / `debug` gem との連携を実際に手元で試す

### 上級

- IRB のソースを読んで、式評価 → 結果表示のパイプラインを追う
- Reline の auto_indent_proc / completion_proc を深堀りして、独自言語用の REPL を作る
- Pry との設計比較(Pry はなぜあの API になっているか / IRB は今どこまで追いついているか)

## 予想される詰まりどころ

- IRB の拡張 API はバージョンで大きく変わっている。使う Ruby / gem バージョンを先に固定する
- Reline の挙動はターミナルエミュレータ依存のものがある(Windows・tmux・特殊キー)
- マルチバイト入力(日本語)周りの表示幅計算

## 参考リンク

- IRB: https://github.com/ruby/irb
- Reline: https://github.com/ruby/reline
- IRB のドキュメント: https://docs.ruby-lang.org/ja/latest/library/irb.html
- debug gem: https://github.com/ruby/debug
- 過去の RubyKaigi の IRB / Reline 発表(aycabta さん、k0kubun さん、st0012 さんなど)

## アウトプットのヒント

- 作った拡張コマンドのデモを REPL で生でやると爆ウケする
- 「このキーを押すとこうなる」の動きはスクショか録画で見せる
- `.irbrc` の晒し合いは知見の宝庫。差分でいいので持ち寄る
