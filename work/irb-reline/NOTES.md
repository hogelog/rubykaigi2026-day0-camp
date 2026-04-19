# IRB / Reline 学習メモ

RubyKaigi 2026 Day 0 合宿の予習として、IRB / Reline の内側を触り
「何が設定で変えられるか」「REPL のパイプラインがどう組み立てられているか」
を手で確認した記録。

- Ruby: `ruby 4.0.2 (2026-03-17 revision d3da9fec82) +PRISM +GC [x86_64-linux-gnu]`
- gem: `irb 1.16.0` / `reline 0.6.3`
- 環境: Linux 6.12.43+deb13-amd64
- 実験スタイル: IRB は対話的なので `IRBRC` 環境変数でダミー `.irbrc` を指定し、
  `IO.popen` で stdin にコマンドを流す方式で非対話的に観察している。

## 01. IRB.conf の中身 (`01_irbconf.rb`)

`require "irb"` しただけでは `IRB.conf` は空 (`size=0`)。`IRB.setup(nil)` を
明示的に呼ぶと 35 エントリが入る。通常は `irb` コマンド起動時に `IRB.start`
経由で setup される。

主要キーのデフォルト値(`IRB.setup(nil)` 直後):

| キー | 値 | 備考 |
| --- | --- | --- |
| `PROMPT_MODE` | `:NULL` | **TTY 判定で :DEFAULT / :NULL を出し分ける**(後述) |
| `AUTO_INDENT` | `true` | Reline の auto_indent_proc に連動 |
| `USE_AUTOCOMPLETE` | `true` | Tab 補完 |
| `USE_COLORIZE` | `true` | 色付け |
| `USE_PAGER` | `true` | `ls` / `show_source` 出力のページャ |
| `SAVE_HISTORY` | `1000` | 履歴行数上限 |
| `HISTORY_FILE` | `nil` | 未設定の場合 Reline が `~/.irb_history` を使う |
| `COMMAND_ALIASES` | `{ :$ => :show_source, :@ => :whereami }` | デフォは 2 個だけ |
| `ECHO`, `ECHO_ON_ASSIGNMENT` | `nil` | CLI フラグで上書き |
| `IRB_LIB_PATH` | `.../gems/irb-1.16.0/lib/irb` | Command ファイルの探索元 |

気づき:

- `COMMAND_ALIASES` は **デフォルトが `$` (show_source) と `@` (whereami) の 2 個だけ**。
  `cd` / `bt` / `irb_info` のような長い名前を自分で短くしたければここに追加する。
  `.irbrc` で `IRB.conf[:COMMAND_ALIASES][:m] = :show_source` のように書くと即有効。
- `:PROMPT` はモードごとに `PROMPT_I` / `PROMPT_S` / `PROMPT_C` / `RETURN` の
  4 本組。`PROMPT_I` は通常行、`PROMPT_S` は文字列継続中、`PROMPT_C` はコード継続中、
  `RETURN` は結果表示のフォーマット。`%N` = アプリ名、`%m` = `self.to_s`、
  `%03n` = 入力行番号 (ゼロ詰め 3 桁)、`%l` = 継続中の quote 文字 (`"` / `'`)、
  `%i` = ネストレベル。
- `PROMPT_MODE :NULL` は `PROMPT_I: nil` で **プロンプトを一切出さない**モード。
  `RETURN: "%s\n"` なので結果だけがクリーンに出る。

## 02. `.irbrc` がいつ読まれるか (`02_irbrc.rb`)

| 起動方法 | `.irbrc` が読まれる? |
| --- | --- |
| `irb` (何もしない) | `~/.irbrc` → `~/.config/irb/irbrc` → `IRBRC` 環境変数 → `./.irbrc` |
| `irb -f` | **読まない** |
| `irb -r /path/to/.irbrc` | **失敗**(require は `.rb` を期待) |
| `IRBRC=/path/to/rc irb` | **読む** ✅ |

**引っかかった点**: `irb -r /path/to/.irbrc` は `.irbrc` を読み込むための常套手段だと
思っていたら `LoadError: cannot load such file -- /tmp/.../.irbrc` で落ちた。
`-r` は `Kernel#require` ベースで `.rb` 拡張子を期待するため、拡張子なしの
`.irbrc` は require できない。**rc を差し替える正解は `IRBRC=...` 環境変数**。
これは対話なしで `.irbrc` の挙動を自動テストする時に必須テクニック。

`.irbrc` で設定できて便利なもの(今回試したもの):

```ruby
# 独自プロンプト
IRB.conf[:PROMPT][:CAMP] = { PROMPT_I: "camp> ", PROMPT_S: "camp* ",
                              PROMPT_C: "camp... ", RETURN: "=> %s\n" }
IRB.conf[:PROMPT_MODE] = :CAMP

# コマンドエイリアス追加
IRB.conf[:COMMAND_ALIASES][:m] = :show_source

# main に生えたヘルパ (top-level def はそのまま REPL で呼べる)
def hi(name = "camp") = "hi, #{name}!"
```

観察結果:

| 試したこと | 結果 |
| --- | --- |
| `hi` / `hi("ruby")` | `"hi, camp!"` / `"hi, ruby!"` — main に定義したメソッドはそのまま IRB から呼べる |
| `IRB.conf[:PROMPT_MODE]` | `:CAMP` — `.irbrc` の設定が反映されている |
| プロンプト表示 | piped stdin では **プロンプト自体が出ない**(`:NULL` モード扱い) |

## 03. PROMPT_MODE の自動切り替え (`03_default_prompt.rb`)

`.irbrc` で PROMPT_MODE を触らなくても、piped stdin では必ず `:NULL` になる。
**`irb/init.rb:140`** に種明かしがある:

```ruby
@CONF[:PROMPT_MODE] = (STDIN.tty? ? :DEFAULT : :NULL)
```

stdin が TTY でなければ `:NULL` を強制する実装。**スクリプトから IRB にコマンドを
流す時に `irb(main):001:0>` の prefix が邪魔にならない**のはこのおかげ。
逆に、シェルから `cat foo.rb | irb > out.txt` のようにすれば、評価結果だけが
クリーンに出せる(ヒアドキュメント評価の簡単代用にもなる)。

## 04. 組み込みコマンド一覧 (`04_commands.rb`)

IRB 1.16.0 の組み込みコマンドは **7 カテゴリ・37 件**。`IRB::Command.commands` に
`{ 名前 => [クラス, [[alias, policy], ...]] }` の形で登録されている。

| カテゴリ | 件数 | 代表例 |
| --- | --- | --- |
| IRB | 9 | `exit`, `history`, `irb_info`, `source`, `context` |
| Debugging | 10 | `debug`, `break`, `step`, `continue`, `backtrace`, `bt` — **全部 debug.gem 委譲** |
| Workspace | 6 | `cd`, `chws`, `pushws`, `popws`, `workspaces` |
| Multi-irb (**DEPRECATED**) | 4 | `irb`, `jobs`, `fg`, `kill` |
| Context | 4 | `ls`, `show_source`, `show_doc`, `whereami` |
| Misc | 3 | `copy`, `edit`, `measure` |
| Help | 1 | `help` / `show_cmds` |

`help` を打つと category 別にセクション分けされた一覧が出る。自分が書いた
拡張コマンドも `category` を指定すれば同じテーブルに並ぶ。

気づき:

- **Multi-irb が DEPRECATED カテゴリ**。`jobs` / `fg` / `kill` で複数 IRB セッションを
  切り替える古い機能は、新しい `cd` / `workspaces` 系に機能が吸収されて非推奨扱い。
  「IRB の勉強で最初に触る機能」としては **古い資料で Multi-irb が出てきたら注意**。
- **Debugging は丸ごと debug.gem への橋渡し**。IRB 内で `debug` と打つと、現在の
  binding をそのまま debug セッションに受け渡す。IRB から debug.gem に移る動線が
  かなり近くに作られている(RubyKaigi 2023 の st0012 のトーク文脈)。
- **Helper method という別カテゴリがある**(`conf` がその唯一のデフォルト)。
  `IRB::HelperMethod::Base` を継承して `IRB::HelperMethod.register(:名前, クラス)`
  すると、**戻り値を持つメソッド**として REPL から呼べる。対して Command は
  「行全体を raw arg として受け取る副作用ベースの "命令"」で、戻り値は評価対象に
  ならない。**値を返したいか / 副作用を起こしたいか** で使い分ける。
- `ExtendCommand = Command` (後方互換のエイリアス)。`IRB::ExtendCommand.equal?(IRB::Command) #=> true`。
  **古い資料の `class Foo < IRB::ExtendCommand::Nop` は今は `IRB::Command::Base`**
  と書くのが新流儀。どちらも動くが新 API を使うと `description`/`category`/`help_message`
  が使える。
- コマンド名は内部名 `irb_ls` と UI 名 `ls` の 2 系統がある。`IRB::Command._register_with_aliases`
  で alias ごとに `NO_OVERRIDE` / `OVERRIDE_PRIVATE_ONLY` / `OVERRIDE_ALL` を指定。
  これは「ユーザの `ls` 変数と組み込み `ls` コマンドのどちらを優先するか」を
  制御する(`command/internal_helpers.rb` と `Command.execute_as_command?` 参照)。

## 05. 拡張コマンドを自作する (`05_custom_command.rb`, `06_help_integration.rb`)

### 5.1 Command(副作用ベース)

```ruby
class CountMethods < IRB::Command::Base
  category    "Camp"
  description "引数のクラスで定義されたメソッドを継承元ごとに集計する"
  help_message <<~HELP
    Usage: count_methods <expr>
    ...
  HELP

  def execute(arg)
    obj   = @irb_context.workspace.binding.eval(arg.to_s.strip)
    klass = obj.is_a?(Module) ? obj : obj.class
    # ... テーブル表示
  end
end
IRB::Command.register(:count_methods, CountMethods)
```

実行結果(`count_methods Integer` で Integer のメソッドを owner 別に):

```
  Integer                         65
  Kernel                          37
  Numeric                         29
  BasicObject                      7
  Comparable                       2
  PP::ObjectMixin                  2
  (total)                        142
```

- `@irb_context` は `IRB::Command::Base#initialize(irb_context)` で渡される
  `IRB::Context` オブジェクト。現在の binding は `@irb_context.workspace.binding`。
- 引数 `arg` は **行末までの文字列**(parse されていない生の引数)。Ruby 式として
  評価したければ自分で `binding.eval(arg)` する。**コマンドは Ruby 構文を受けない
  「シェル的な命令」**というのが設計思想。
- `category` を指定すると `help` のテーブルにその名前でセクションが生え、
  自作コマンドがちゃんと列挙される。`description` は 1 行、`help_message` は
  `help <名前>` で表示される複数行 doc。

### 5.2 HelperMethod(戻り値ベース)

```ruby
class SelfClass < IRB::HelperMethod::Base
  description "現在のトップレベル self の class を返す"
  def execute
    IRB.CurrentContext.workspace.binding.receiver.class
  end
end
IRB::HelperMethod.register(:self_class, SelfClass)
```

**落とし穴**: `IRB::HelperMethod::Base` は Singleton で、**`@irb_context` は渡されない**。
最初 Command と同じ `@irb_context.workspace...` と書いて `NoMethodError: undefined
method 'workspace' for nil` を食らった。`IRB.CurrentContext` をグローバルに引くのが正しい。

`workspace.rb:167-179` の `HelpersContainer#install_helper_methods` を読むと、
helper は `define_method name do |*args, **opts, &block|
helper_method_class.instance.execute(*args, **opts, &block) end` で main に
install されている。**main で直接呼べるメソッド**として生えるので `self_class` と
書くだけで呼べるし、`self_class.ancestors.first(3)` のようにチェインもできる。

### 5.3 Command と HelperMethod の使い分け

| 軸 | Command | HelperMethod |
| --- | --- | --- |
| 呼び方 | 行頭に名前を書く(シェル的) | Ruby メソッド呼び出し |
| 引数 | 行末までの生文字列 1 つ | 通常の Ruby 引数 |
| 戻り値 | 使われない | そのまま評価値になる |
| context | `@irb_context` が渡る | 自分で `IRB.CurrentContext` を引く |
| 用途 | `ls foo`, `show_source Foo#bar`, `edit` | `conf`, 現在のオブジェクトを返す系 |

**判断基準**: 結果を `.` で繋いで使いたい / 変数に束縛したいなら HelperMethod、
単独で副作用を起こすコマンドなら Command。

### 5.4 新 API と旧 API の差

- 旧: `class Foo < IRB::ExtendCommand::Nop` + `IRB::ExtendCommandBundle.def_extend_command`
- 新: `class Foo < IRB::Command::Base` + `IRB::Command.register(:name, Foo)`
- `IRB::ExtendCommand = IRB::Command`、`IRB::Command::Base` 内の `Nop = Base` なので
  **旧名前でも動く**。が、新 API のほうが `category` / `description` / `help_message` が
  ファーストクラスで、`help <cmd>` にそのまま繋がる。**新規に書くなら新 API 一択**。

### 5.5 `help` 出力への統合 (`06_help_integration.rb`)

自作 Command は `category "Camp"` と書くだけで、`help` コマンドの出力に
新しいセクションとして現れる:

```
Camp
  camp_hello     合宿挨拶

Helper methods
  conf           Returns the current IRB context.
  camp_size      合宿 helper: 42 を返すだけ
```

- category を指定しないと `"No category"` セクションに入る(あまり見栄えよくない)。
- HelperMethod は常に `"Helper methods"` セクション固定(category の概念がない)。

## 06. Reline.readline で最小 REPL (`07_reline_repl.rb`, `08_reline_repl_pty.rb`)

### 6.1 コアとなる 4 つの API

| API | 型 | 役割 |
| --- | --- | --- |
| `Reline.readline(prompt, with_hist)` | `String \| nil` | 1 行入力。`nil` なら EOF(Ctrl-D) |
| `Reline.readmultiline(prompt, with_hist) { \|buf\| done? }` | `String` | 改行で完了判定ブロックを呼ぶ複数行入力 |
| `Reline.completion_proc = ->(input) { candidates }` | 書込 | Tab 補完の候補列挙 |
| `Reline::HISTORY` | Array 的 | 履歴(`<<` / `last` / `clear` / `to_a`) |

小さな REPL(`07_reline_repl.rb`)の要旨:

```ruby
Reline.completion_proc = ->(input) do
  VOCAB.select { |w| w.start_with?(input) }   # 単純な前方一致
end

loop do
  line = Reline.readline("mini> ", true)  # with_history=true で自動追加
  break if line.nil?
  # ... 評価 ...
end
```

### 6.2 非対話環境での観察方法 (`08_reline_repl_pty.rb`)

Reline は **端末(TTY)前提**なので piped stdin では本来の挙動にならない。
対話テストを再現したければ **stdlib の `PTY.spawn`** を使う:

```ruby
PTY.spawn({ "TERM" => "xterm-256color" }, "ruby", script) do |r, w, pid|
  inputs = ["help\r", "add 3 4\r", "squ\t 7\r", "history\r", "quit\r"]
  inputs.each { |s| sleep 0.15; w.write(s); w.flush }
end
```

PTY 経由で走らせると、**本物のキー入力と同等**のやり取りが再現できる。
これは IRB / Reline の挙動を CI に乗せる時の正攻法。

### 6.3 観察できたこと

| 入力 | 観察 |
| --- | --- |
| `help\r` | コマンドハンドラが動き、`VOCAB` が列挙される |
| `add 3 4\r` | `=> 7.0`(履歴に `add 3 4` が残る) |
| `squ\t 7\r` | **Tab で `squ` が `square` に展開**された。`completion_proc` が効いている |
| `history\r` | 直前 4 件 + `history` 自身が番号付きで列挙される |
| `quit\r` | ループ脱出 |

### 6.4 起動時の端末能力プロービング

PTY の生出力を見ると、最初のプロンプト表示前に Reline が面白いことをしている:

```
[1G ▽ [6n [1G [K [6n
```

- `\e[1G` カーソルを行頭へ
- `▽` を 1 文字描く
- `\e[6n` Device Status Report(カーソル位置を返せ)を要求
- 帰ってきた X 座標から、**その端末における `▽` の文字幅が 1 か 2 か**を測る
- 結果を再度消して (`\e[K`) プロンプト描画に入る

これが **ima1zumi が取り組んでいる「端末ごとの曖昧幅(ambiguous width)問題」
の中核**。絵文字・全角記号・East Asian 文字の表示幅は端末依存で、Reline は
実測して `Reline.ambiguous_width` を決める。`Reline::IOGate::ANSI` / 内部の
`IOGate#cursor_pos_reqeust` が実装の入口。

### 6.5 その他の観察された ANSI 制御

| シーケンス | 意味 |
| --- | --- |
| `\e[?2004h` / `\e[?2004l` | bracketed paste mode on/off(貼付け時に `\e[200~...\e[201~` で囲う) |
| `\e[?25l` / `\e[?25h` | カーソル非表示/表示(再描画ちらつき防止) |
| `\e[6n` | Device Status Report(上述) |
| `\e[1G` / `\e[K` | 行頭移動 / 行末クリア(再描画の基本) |

**気づき**: Reline は毎回のプロンプト描画で「非表示 → クリア → 書き直し → 再表示」
の順で更新している。Readline(C 実装)に比べると ANSI 制御がゴリゴリ発行されるが、
**Ruby だけでマルチライン編集・補完を実現するために必要なコスト**。pure Ruby で
ここまでやっていることがむしろすごい。

## 07. マルチラインと auto_indent_proc (`09_multiline.rb`, `10_multiline_pty.rb`)

### 7.1 readmultiline の契約

```ruby
buf = Reline.readmultiline(prompt, with_hist) do |input|
  balanced?(input)        # true を返すと入力確定
end
```

- ブロックは **Enter(`\n`) が入るたび**呼ばれ、`input` 全体(現在までの複数行)を受ける
- `true` を返した瞬間に readmultiline がリターン
- `false` を返すと継続入力になる

**観察**:
- `1 + 1\r` → 最初から balanced なので 1 行で確定
- `def greet\r "hi"\r end\r` → `opens=1, closes=1` になる 3 行目の `end\r` で確定

### 7.2 auto_indent_proc のシグネチャ

```ruby
Reline.auto_indent_proc = ->(lines, line_index, byte_pointer, is_newline) { indent_in_spaces }
```

- `lines` : 現在のバッファ(`String[]`、各行は改行なし)
- `line_index` : **カーソルのある行**
- `byte_pointer` : 行内のバイト位置
- `is_newline` : **新しい行が挿入された直後**なら true。行内文字変更なら false

Reline は **キー 1 つ押すたびにこれを呼ぶ**。戻り値を **その行のインデント量
(先頭スペース数)**として扱い、行を `' ' * indent + line.lstrip` に置き換える。
つまりユーザが打鍵するたびに行全体が再整形される(「`end` を打った瞬間に
行が勝手に左へ寄る」のはこれ)。

### 7.3 観察(`end` 入力で dedent が発火)

`INDENT_LOG` に吐いたログの抜粋(`if true / def inner / 42 / end / end` を入力):

```
[indent] line=3 newline=false lines=[..,"    42", "    en", ""] => 4
[indent] line=3 newline=false lines=[..,"    42", "    end", ""] => 2   # ← end 完成で dedent
[indent] line=3 newline=true  lines=[..,"    42", ""]             => 4
[indent] line=3 newline=false lines=[..,"    42", "  end"]         => 2   # 置換後の再計算
[indent] line=4 newline=false lines=[..,"  end", "  end", ""]      => 0   # 外側 end も 0 へ
```

- `end` を 1 文字ずつ打つ `e` → `en` → `end` で、**`end` が完成した瞬間に
  返り値が 4 → 2 に落ちる**。Reline がそれを受けて行頭を `"    "` → `"  "` に詰める。
- `newline=true` は「Enter で新しい行が挿入された直後」、`newline=false` は「行内編集」。
  どちらも auto_indent_proc が呼ばれるが、IRB はこの区別を「前の行の完成度判定」と
  「現在行の再インデント」で使い分けている。

### 7.4 `in_pasting?` の落とし穴

auto_indent_proc が **呼ばれない** 場合がある。`line_editor.rb:282` の条件:

```ruby
if @auto_indent_proc && !@in_pasting
```

**`@in_pasting`** は `ansi.rb:155` の `in_pasting?` で決まる:

```ruby
def in_pasting?
  not empty_buffer?        # 次の読みがブロックせずに取れる = pasting
end
```

つまり **「次の文字が即読める = 貼り付け中」** と判定する。PTY で
`"def greet\r"` をまとめて `write` すると、Reline 側では全文字が
一気に available になり、**全部 pasting 扱いで auto_indent がスキップ**される。

検証のためには 1 文字ずつ `sleep 0.02` を挟んで送る必要があった:

```ruby
s.each_char do |c|
  w.write(c); w.flush; sleep 0.02
end
```

これは **IRB で "def ... end を貼り付けると勝手にインデントが崩れない"** 挙動の
裏方実装でもある。人間の打鍵速度と貼り付けを文字間隔で区別している。
(`\e[200~` / `\e[201~` の bracketed paste が効く端末ならそれで、効かない
端末では時間ベースで判定)

### 7.5 IRB のマルチラインはどう拡張しているか

IRB は Reline の auto_indent_proc に **ripper/prism ベースの実パーサ**を差し込んで
いる (`ruby-lex.rb` 参照)。今回書いた「正規表現で def/end を数える」式では
`"end"` という string literal や `# end` コメントを誤検出する。IRB は
**ruby-lex.rb で Ripper を回して token 単位**で open/close を数えるので、
`"end in string"` のような文字列中の `end` を無視できる。**Reline の API は
汎用で、Ruby らしさは IRB 側の proc 実装が担っている**という分業。

## 08. IRB の式評価パイプライン (`11_pipeline_probe.rb`)

`TracePoint(:call)` で IRB 関連メソッドだけフィルタして、1 本の入力 (`1 + 2`) が
どう流れるかを追った。骨格:

```
IRB.start
└─ Irb#run                                # SIGINT trap + catch(:IRB_EXIT) + eval_input
   └─ Irb#eval_input                      # 本体ループ
      ├─ Irb#configure_io                 # Reline に check_termination / dynamic_prompt を接続
      └─ Irb#each_top_level_statement
         └─ loop:
            ├─ Irb#readmultiline          # Reline 経由で 1 ユニット読む
            │  ├─ generate_prompt
            │  └─ read_input_nomultiline / read_input  # 実際の gets
            ├─ Irb#command?              (事前チェック) -> parse_input
            ├─ Irb#parse_input
            │  └─ Context#parse_input    # コマンド vs 式を判定
            │                            # Statement::{Command|Expression|EmptyInput|IncorrectAlias} を返す
            └─ Context#evaluate(statement, line_no)
               ├─ (Expression)  Context#evaluate_expression
               │                 └─ Workspace#evaluate
               │                     └─ eval(code, @binding, path, line_no)
               │                 set_last_value   # `_` にも結果を束縛
               │                 output_value    # inspect_last_value を puts
               └─ (Command)     Statement#command_class.execute(ctx, arg)
                                 # 戻り値は捨てる。suppresses_echo? = true
```

### 8.1 Statement の 4 系統

`lib/irb/statement.rb` に定義:

| Statement | is_assignment? | suppresses_echo? | 発火条件 |
| --- | --- | --- | --- |
| `EmptyInput` | false | **true** | 入力が空行 / `\n` のみ |
| `Expression` | 動的(Ripper で判定) | `;\s*\z` なら true | 通常の Ruby 式 |
| `Command` | false | **true** | 行頭が組み込みコマンド名で、local 変数より優先される時 |
| `IncorrectAlias` | false | true | エイリアス先が存在しない時の警告 |

コマンドと式の判別ロジック(`context.rb:596` `parse_input`):

- 行数が 1 行で
- 先頭トークン名が `local_variables` に含まれていなくて
- `is_assignment_expression` でも `==` / `=~` でもなくて
- `Command.load_command(名前)` が非 nil で
- `Command.execute_as_command?(名前, public_method:, private_method:)` が true

を全て満たす時だけ `Statement::Command`。**同名のローカル変数があれば式扱い**に
なるのは、`ls = 1; ls` と書いた時にコマンドではなく変数参照になってほしいから。

### 8.2 Reline/IRB 境界の proc

`Irb#configure_io` (irb.rb:302) で IO(Reline バックエンド)に 2 つの proc を注入:

| proc | シグネチャ | 役割 |
| --- | --- | --- |
| `check_termination` | `->(code) { bool }` | 入力確定判定。Ripper で lex して open が 0 かつ構文 valid なら true |
| `dynamic_prompt` | `->(lines) { [prompt, prompt, ...] }` | 各行のプロンプト生成(`%N(%m):001:0>` など) |

**これが Reline と IRB の責任分界**: Reline は編集・補完・描画のインフラ、
IRB は `check_termination` で Ruby 構文を知っている閉じ判定、
`dynamic_prompt` で `PROMPT_C`(継続)/`PROMPT_S`(文字列継続)の出し分けを担う。

### 8.3 piped stdin では nomultiline フォールバック

`configure_io` の中で `@context.io.respond_to?(:check_termination)` を見ている。
piped stdin では `StdioInputMethod` が選ばれて `check_termination` を持たないので、
`readmultiline` → `read_input_nomultiline` に分岐する。この経路は RubyLex で
**自前で** 入力の構文終端を判定する(`ruby-lex.rb:171 check_code_state`)。

### 8.4 exit は例外ではなく `throw :IRB_EXIT`

`command/force_exit.rb:12` で `throw :IRB_EXIT, true`。`Irb#run` 側で
`catch(:IRB_EXIT)` しているのでループを綺麗に抜ける。**SystemExit で飛ばさない**のは、
`binding.irb` のように別プログラムに埋め込まれている場合に上位コードまで
殺さないため。

### 8.5 `assignment_expression?` の実装

`ruby-lex.rb:190` の `assignment_expression?` は **`Ripper.sexp` で S 式を作って
末尾が assign 系かどうか**を見る。これが正しく判定できるから `x = 1` の時に
`=> 1` を抑制する `--truncate-echo-on-assignment` が効く。古い IRB は正規表現で
やっていて、`x = Foo.new do; y = 1; end` のような入れ子で誤動作した過去がある。

### 8.6 Ripper → Prism への移行ポイント

`ruby-lex.rb:172` `self.class.ripper_lex_without_warning` は名前どおり Ripper。
Ruby 4.0 の IRB 1.16.0 ではまだ Ripper が現役。Prism 化は段階的に進行中で、
RubyKaigi 2026 でもこの周辺の話題は十分ありうる(k0kubun / st0012 の 2024〜2025
トーク文脈を継ぐ先)。
