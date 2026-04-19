# IRB / Reline — Ruby の REPL を分解して遊ぶ

## なぜ触るのか

IRB は毎日使っているのに、その内側を覗いたことがある人は意外と少ない。Reline は readline 互換を目指した Ruby 製のライン入力ライブラリで、IRB の裏で動いている。

最近の IRB はデバッガ統合・シンタックスハイライト・ページャ連携など、ものすごく進化している。RubyKaigi では IRB / Reline のメンテナから毎年のように新機能の話がある領域。

## 触って分かると嬉しいこと

- IRB の Command 機能と、自作コマンドの追加方法
- **`IRB::Command::Base`(副作用の命令)と `IRB::HelperMethod::Base`(戻り値を返す
  メソッド)の使い分け**。`ls foo` は前者、`conf.main.class` は後者
- Reline が提供しているキーバインド・補完 API
- ターミナル制御(エスケープシーケンス・window size)の基本
- `.irbrc` でできることの広さ

## 取り組みアイデア(難易度順)

### 入門

- `.irbrc` で自分専用エイリアス・ヘルパを整える
- **`.irbrc` を差し替えて挙動を試したい時は `IRBRC=/tmp/myrc irb` と環境変数で
  指定する**(`irb -r /path/to/.irbrc` は `Kernel#require` 経由で `.rb` 拡張子を
  要求するため動かない)
- `IRB.conf` を眺めて、プロンプト・履歴・カラーリングを変える
- `irb --help` と `help` コマンドで組み込みコマンドを一周する。カテゴリ分け
  (IRB / Workspace / Debugging / Context / Misc / Help)と `COMMAND_ALIASES`
  (デフォは `$` → `show_source`、`@` → `whereami` の 2 個だけ)を押さえる

### 中級

- IRB の拡張コマンドを自作する。新 API は `IRB::Command::Base` を継承して
  `IRB::Command.register(:name, MyCmd)`。`category` / `description` / `help_message`
  を宣言すると `help` の一覧に自分のセクションとして並ぶ
  - 例: 「現在のオブジェクトのメソッド一覧を見やすく出す」「直前の例外を `binding.irb` 相当に落とす」
  - **戻り値を変数に束縛したい**なら `IRB::HelperMethod::Base` + `IRB::HelperMethod.register`。
    こちらはシングルトンとして main に生えるので `conf.main` のように `.` 連鎖できる。
    **コンテキストは渡されないので `IRB.CurrentContext` を自分で引く**
- Reline の API を使って簡単な REPL ライクな CLI を書いてみる(`Reline.readline`,
  `Reline::HISTORY`, `Reline.completion_proc = ->(prefix) { ... }`, マルチラインは
  `Reline.readmultiline(prompt, true) { |buf| terminated?(buf) }`)
- 非対話の環境で Reline の挙動を観察したいときは **標準添付の `PTY.spawn`** で疑似端末を
  張る。`w.write(c); w.flush; sleep 0.02` で 1 文字ずつ送ると、起動時の `▽` + CSI 6n
  (曖昧幅の実測プローブ)や `\e[?25l` / `\e[K` による毎キーの再描画が生で見える
- `binding.irb` / `debug` gem との連携を実際に手元で試す

### 上級

- IRB のソースを読んで、式評価 → 結果表示のパイプラインを追う。入口は
  `lib/irb.rb` の `Irb#run` → `#eval_input` → `#each_top_level_statement` →
  `#readmultiline` と `#parse_input`。コマンドと式の判別は
  `lib/irb/context.rb` の `Context#parse_input` で、結果は
  `Statement::{Expression, Command, EmptyInput, IncorrectAlias}` の 4 系統に分岐する。
  Reline との境界は `Irb#configure_io` が IO に差す `check_termination` と
  `dynamic_prompt` の 2 proc。exit は `throw :IRB_EXIT`(`binding.irb` の呼び出し元を
  殺さないため)
- Reline の auto_indent_proc / completion_proc を深堀りして、独自言語用の REPL を作る

## 予想される詰まりどころ

- IRB の拡張 API はバージョンで大きく変わっている。使う Ruby / gem バージョンを先に固定する
- **`IRB::ExtendCommand` は現行版 `IRB::Command` の単なる別名**(`IRB::ExtendCommand.equal?(IRB::Command)
  #=> true`)、`IRB::ExtendCommand::Nop` は `IRB::Command::Base` のエイリアス。
  旧資料のコードは動くが、新規に書くなら `IRB::Command::Base` + `IRB::Command.register` に揃える
- **Multi-irb(`jobs` / `fg` / `kill` / ネスト `irb`)は `help` 上で `DEPRECATED`
  カテゴリ**。古いブログに出てきたら「潜って作業する」は `cd` / `pushws` / `popws` /
  `workspaces` に、セッション切替は `binding.irb` に読み替える
- **`auto_indent_proc` を設定したのに呼ばれない**場合、Reline の `in_pasting?` 判定を疑う。
  「次の文字が即読める = 貼り付け中」と見なされている間はインデント自動調整が
  スキップされる。動作確認は 1 文字ずつ `sleep 0.02` 挟んで送るか、bracketed paste
  (`\e[200~ ... \e[201~`)で明示的に囲う
- **`IRB.conf[:PROMPT_MODE]` は標準入力が端末でないと `:NULL` に自動切替**される
  (`init.rb:140` の `STDIN.tty? ? :DEFAULT : :NULL`)。`echo '1+2' | irb` で結果だけが
  クリーンに出るのはこのおかげ。「パイプで実行したらプロンプトが消えた」は仕様
- Reline の挙動はターミナルエミュレータ依存のものがある(Windows・tmux・特殊キー)
- マルチバイト入力(日本語)周りの表示幅計算

## 参考リンク

IRB / Reline は ima1zumi(STORES)が現行の主要メンテナの一人。補完・カラーリング・Reline の表示幅計算まわりは彼女の仕事が大きい。

- IRB: https://github.com/ruby/irb
- Reline: https://github.com/ruby/reline
- IRB のドキュメント: https://docs.ruby-lang.org/ja/latest/library/irb.html
- debug gem: https://github.com/ruby/debug
- **ima1zumi の RubyKaigi 過去発表**: https://rubykaigi.org/2025/presentations/ima1zumi.html など各年のアーカイブ。IRB / Reline / 文字幅・エンコーディング周りの最新動向を追える
- 歴史的経緯を追いたい場合は aycabta さん、k0kubun さん、st0012 さんの IRB / Reline 発表も合わせて

## アウトプットのヒント

- 作った拡張コマンドのデモを REPL で生でやると爆ウケする
- 「このキーを押すとこうなる」の動きはスクショか録画で見せる
- `.irbrc` の晒し合いは知見の宝庫。差分でいいので持ち寄る
