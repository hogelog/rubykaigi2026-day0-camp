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
