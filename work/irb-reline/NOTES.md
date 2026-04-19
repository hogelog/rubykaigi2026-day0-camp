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
