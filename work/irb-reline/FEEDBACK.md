# themes/irb-reline.md への学習者フィードバック

Ruby 4.0.2 + `irb 1.16.0` + `reline 0.6.3` で入門・中級・上級(式評価パイプライン
読解)を一通り触った結果、`themes/irb-reline.md` に対して感じたことのまとめ。

## よかった点

- 「触って分かると嬉しいこと」が **Command 機能 / Reline API / ターミナル制御 /
  .irbrc の広さ** の 4 軸で整理されていて、そのまま学習メニューとして機能した。
  特に「ターミナル制御(エスケープシーケンス・window size)の基本」を触って
  分かると嬉しいとあったおかげで、PTY で生出力を見る方向の実験に踏み込めた。
- **予想される詰まりどころ**に「IRB の拡張 API はバージョンで大きく変わっている」
  と書いてあったおかげで、実際に `IRB::ExtendCommand` と `IRB::Command` の
  両方が動くことに戸惑わず「これは後方互換の同一実体だな」と腑に落ちた。
- 参考リンクの ima1zumi 紹介が、PTY で観察できた「起動時の `▽` + CSI 6n」
  (ambiguous width プローブ)を見た時に「これ、彼女のトークの文脈だ」と
  繋がる導線になっていた。

## もう少しあると嬉しかった点

以下は「初見で詰まった」「書いてあれば時間を節約できた」系の具体フィードバック。
各項目は「発生した状況 → こういう 1 行があれば救われる」形式で書く。

### 1. `.irbrc` を差し替えて自動テストするには `IRBRC=` 環境変数

初見で `.irbrc` に独自コマンドを書いて自動テスト(非対話)したくなった時、
最初に手が伸びたのが `irb -r /path/to/.irbrc`。これは **`LoadError: cannot load
such file -- /path/to/.irbrc`** で落ちる。`-r` は `Kernel#require` ベースで
`.rb` 拡張子を要求するため、`.irbrc` を load できない。

正解は **`IRBRC=/path/to/.irbrc irb`** の環境変数経由。これは IRB を自動テストに
かける時の必須テクニックだが、ガイドにも公式マニュアルにも目立つ形では書かれて
いない。以下のような 1 行が「入門」節の最後にあると救われる:

> `.irbrc` を差し替えて実験したい時は `IRBRC=/tmp/mytestrc irb` のように
> 環境変数で指定する。`irb -r` は `.rb` 前提なので使えない。

### 2. `IRB::Command::Base` と `IRB::HelperMethod::Base` の使い分け

ガイドには「IRB の拡張コマンドを自作する(`IRB::ExtendCommand` を継承 /
**新しい Command API** を使う)」と書かれているが、**Command** と **HelperMethod**
という 2 系統がある点は書かれていない。

- `IRB::Command::Base` 継承: 行頭に置く「命令」。`arg` は行末まで生文字列。
  **戻り値は使われない**。`@irb_context` で context が渡る。
- `IRB::HelperMethod::Base` 継承: `conf` のような **戻り値を返す通常メソッド**。
  Singleton として main に install される。**context は渡されない**ので、
  必要なら `IRB.CurrentContext` を自分で引く。

最初 HelperMethod で `@irb_context.workspace...` と書いて `NoMethodError: undefined
method 'workspace' for nil` を食らった。この使い分けが 1 表でまとまっていると
迷わない(NOTES.md 5.3 節にその表を作った)。

ガイドに追加すると良さそう:

> 拡張には 2 系統ある。結果を `.` で繋ぎたい(`conf.main.class` 等)なら
> `IRB::HelperMethod::Base`、副作用を起こす命令(`ls Foo`, `edit path` 等)なら
> `IRB::Command::Base` を継承する。前者は context が渡らないので自分で
> `IRB.CurrentContext` を引く必要がある。

### 3. `IRB::ExtendCommand = IRB::Command` と明記する

ガイドの「`IRB::ExtendCommand` を継承」という表現は、**旧 API がまだあるように
見える**が、実際は:

```ruby
IRB::ExtendCommand.equal?(IRB::Command)  #=> true
IRB::Command::Base::Nop                  # Nop = Base のエイリアス
```

で、**旧名前は新実装の別名**。新規に書くなら `IRB::Command::Base` + `IRB::Command.register`
の一択でよい。ガイドに 1 行:

> 旧資料に出てくる `IRB::ExtendCommand::Nop` は現行では `IRB::Command::Base` の
> エイリアス。新規に書くなら `IRB::Command::Base` + `IRB::Command.register(:name, MyCmd)`
> を使う。`category` / `description` / `help_message` が宣言的に書けるのはこちら。

### 4. Multi-irb が DEPRECATED カテゴリに入った事実

`help` を打つと `Multi-irb (DEPRECATED)` というセクションが見える。`irb` / `jobs`
/ `fg` / `kill` で複数 IRB セッションを切り替える古い機能は非推奨扱いで、
**新しい `cd` / `workspaces` 系に置き換わっている**。

ガイドの「`irb --help` と `help` コマンドで組み込みコマンドを一周する」に 1 行:

> 複数セッションを切り替える `jobs` / `fg` は Multi-irb (DEPRECATED) カテゴリ。
> 同じことは `cd`(オブジェクトに潜る) / `pushws` / `popws` / `workspaces` で
> できるので、古いブログの `jobs` 記述は置き換えて読むとよい。

### 5. ターミナル制御を観察する方法:PTY.spawn

ガイドは「ターミナル制御の基本」を学ぶテーマとして挙げているが、**どうやって
観察するか**の入り口が書かれていない。非対話で Reline の挙動を見るには、
**stdlib の `PTY.spawn`** で疑似端末を張るのが定石。

```ruby
require "pty"
PTY.spawn({ "TERM" => "xterm-256color" }, "ruby", "repl.rb") do |r, w, pid|
  ["help\r", "squ\t"].each { |s| s.each_char { |c| w.write(c); w.flush; sleep 0.02 } }
  buf = r.readpartial(4096) rescue ""
end
```

観察すると、Reline は起動時に `▽` + `CSI 6n` で **曖昧幅を実測**し、編集のたびに
`\e[?25l` / `\e[K` / `\e[1G` で再描画している。これは ima1zumi のトークと
一直線に繋がる話で、**Reline の面白さを掴むのに一番近道**。ガイドの中級〜上級の
補足として:

> Reline を非対話で観察したければ stdlib の `PTY.spawn` が正攻法。
> 起動直後の `▽` + `\e[6n` は ambiguous width の実測プローブで、これが
> ima1zumi の文字幅仕事の中核。

### 6. `auto_indent_proc` が呼ばれない罠(in_pasting? 判定)

自分で `Reline.auto_indent_proc = ...` を仕込んだのに「何も起きない」で
30 分溶かした。原因は `line_editor.rb:282` の:

```ruby
if @auto_indent_proc && !@in_pasting
```

`@in_pasting` は「次の文字が即 read できる = 貼り付け中」というヒューリスティック
(`reline/io/ansi.rb:155 in_pasting?`)。PTY で複数文字をまとめて `write` すると
**全部 pasting 扱いで auto_indent がスキップ**される。1 文字ずつ `sleep 0.02` で
送ると人間の打鍵相当になって proc が呼ばれる。

これは同時に **IRB で `def ... end` を貼り付けても勝手にインデントを壊さない**
挙動の裏方実装でもある。ガイドの「Reline の auto_indent_proc / completion_proc
を深堀り」の隣に 1 行:

> `auto_indent_proc` が呼ばれないように見えたら、Reline の **pasting 判定**を
> 疑う。貼り付け中(=複数文字が即時 read できる状況)は auto_indent を
> スキップする設計になっている。テスト時は 1 文字ずつ sleep を挟んで送るか、
> bracketed paste `\e[200~ ... \e[201~` を使う。

### 7. piped stdin では PROMPT_MODE が :NULL に切り替わる

`cat foo.rb | irb` で出力を流したい時、**`irb(main):001:0>` の prefix を手で消す
必要はない**。IRB は `init.rb:140`:

```ruby
@CONF[:PROMPT_MODE] = (STDIN.tty? ? :DEFAULT : :NULL)
```

で自動的に `:NULL`(プロンプト無し)に切り替わる。結果として `=> value\n` だけが
きれいに出る。ガイドに 1 行あると小技として役立つ:

> stdin が TTY でない場合、IRB は自動で PROMPT_MODE を `:NULL` に切り替える。
> `echo '1+2' | irb` で `3` だけがクリーンに取れる。ヒアドキュメント評価の
> 簡単代用になる。

### 8. 上級課題への入り口:式評価パイプライン

ガイドは「上級: IRB のソースを読んで式評価パイプラインを追う」としか書いていない。
**どこから読むか**の指差しがないと `lib/irb/` の 30+ ファイル前にひるむ。
以下の 1 段落があると「読める」感覚に入れる:

> 追うべき入り口は `lib/irb.rb` の `IRB::Irb#run` → `#eval_input` →
> `#each_top_level_statement` → `#readmultiline` と `#parse_input`。
> 式とコマンドの判別は `lib/irb/context.rb` の `Context#parse_input` で、
> `Statement::{Expression, Command, EmptyInput, IncorrectAlias}` に分岐する。
> Reline との境界は `Irb#configure_io` で、IO に `check_termination` と
> `dynamic_prompt` の 2 つの proc を差し込んでいる。exit は `throw :IRB_EXIT`。

TracePoint で骨格を吐かせるやり方(この work の `11_pipeline_probe.rb` 参照)
も紹介していい。30 行で IRB 内部の呼び出し順が可視化できる。

### 9. 道具の限界

今回 **検証できなかった**領域も明示しておく。ガイドや次の挑戦者のために:

- **Windows / Windows Terminal での挙動**: `reline/io/windows.rb` の存在は
  確認したが、Linux からは触れない。色・補完・ambiguous width の挙動が
  Unix 系と違う可能性がある。
- **`debug` gem との統合の中身**: `debug` / `break` / `step` が Debug コマンド
  経由で debug.gem に橋渡しされる流れは見たが、**どこで binding が受け渡される
  か**までは追えていない。`command/debug.rb` と `debug.rb` を併読する必要あり。
- **Prism パーサへの切り替え**: `ruby-lex.rb` は Ripper のまま。`lib/irb/` に
  Prism 側の実装があるかは未確認。

## ガイドのメンタルモデルが古い箇所

- 「IRB::ExtendCommand を継承」: 現在は `IRB::Command::Base` が **新 API**、
  `IRB::ExtendCommand` は単なる別名。新規に書くなら `IRB::Command::Base` 一択。
- 「Multi-irb で session を切り替える」系の記述(別ガイドで見かけた場合):
  1.16 時点で DEPRECATED カテゴリに追いやられている。`cd` / `workspaces` を
  先に触るのが今の流儀。

## アウトプットのヒント(ガイドの該当節に追加できると良い)

現在のガイドは「拡張コマンドのデモを REPL で生でやると爆ウケする」と書かれて
いる。これに加えて:

> **録画したい時のコツ**: `asciinema rec session.cast` で IRB セッションを
> キャスト化すると、blog 向けに貼れる。色情報も保持される。
>
> **PTY で再現可能な挙動を撮る**: 対話セッションを script 化して再現したい
> 場合、`PTY.spawn` + `w.write(key, flush); sleep N` のループが使える。
> 補完・履歴・auto_indent を含めて機械的にリプレイできる。
