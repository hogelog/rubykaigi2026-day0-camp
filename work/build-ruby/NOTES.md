# build-ruby 観察ログ

## 環境

- OS: Debian GNU/Linux 13 (trixie)
- CPU / nproc: `nproc` で確認(ビルド並列度に使う)
- Ruby: `ruby 4.0.2 (2026-03-17 revision d3da9fec82) +PRISM +GC [x86_64-linux-gnu]`(system、`/usr/bin/ruby`)
- mise: 2026.2.22(ruby は未管理)
- ruby/ruby clone: `~/repos/ruby`(origin/master から 348 commits behind @ 開始時点)

## 00. 依存パッケージの確認とインストール

スクリプト: `00_install_deps.sh`。ガイド `themes/build-ruby.md` の Ubuntu/Debian 用 apt-get リストに対して、
`dpkg-query` で入っているものは skip し、差分だけ `sudo apt-get install -y` に渡す。

### 開始時点の状態(スクリプト実行前)

| パッケージ | 状態 |
|---|---|
| build-essential | OK |
| autoconf | 未インストール |
| bison | 未インストール |
| libssl-dev | 未インストール |
| libreadline-dev | 未インストール |
| zlib1g-dev | 未インストール |
| libyaml-dev | OK |
| libffi-dev | 未インストール |
| libgmp-dev | OK |
| rustc | 未インストール |

- YAML / GMP は何かの拍子に入っていた(他パッケージの依存か)。それ以外は落とされていた。
- `rustc` は YJIT に必須(1.58 以上)。Debian 13 (trixie) の apt 版は余裕で満たす想定。

### 実行後の状態

| ツール | バージョン |
|---|---|
| autoconf | 2.72 |
| bison | 3.8.2 |
| rustc | 1.85.0 (2025-02-17) |
| libssl-dev | 3.5.5 |
| libreadline-dev | 8.2 |
| zlib1g-dev | 1.3.1 |
| libffi-dev | 3.4.8 |

### 気づき

- Debian 13 (trixie) 標準の apt で `rustc 1.85` が入る。ガイドが求める 1.58 に余裕で届くので、trixie 上では **rustup を別途入れる必要がない**(macOS の Homebrew や古い Ubuntu の rustup 誘導は、ここではカットできる)。
- `bison 3.8.2` / `autoconf 2.72` も問題なし。macOS の「bison 古すぎ罠」は Linux 側では踏まない。
- 依存総量は体感 200MB 弱(update + install)。合宿会場の Wi-Fi で初回に入れるとキツいので、事前に済ませるべき実作業として最初にくる。

## 01. ruby/ruby を origin/master に追随

スクリプト: `01_fetch_master.sh`。`~/repos/ruby` を fast-forward only で追随させ、前後の HEAD / API バージョンを出力する。

| 項目 | 値 |
|---|---|
| fetch 前 HEAD | `634707a725`(Mar 28 時点、origin/master から 348 commits behind) |
| fetch 後 HEAD | `f39318083e`(2026-04-19 07:19 UTC、[DOC] Update bundled gems list) |
| API バージョン | 4.1(= master は **Ruby 4.1.0dev** を育てている) |
| RUBY_PATCHLEVEL | -1(dev ビルドのマーカー) |
| master 総コミット数 | 98,411 |

### 気づき

- Ruby 4.0.2 の system ruby と master の差分は「もう 4.1 を育て始めている」段階。つまり **master をビルドすると `ruby -v` が `4.1.0dev` になる**。合宿で「master の挙動」という時、それは 4.1.0dev のことを指す。
- ガイドは「`ruby 4.1.0dev (...)`」と書いているが、この 4.1 は `include/ruby/version.h` の `RUBY_API_VERSION_MAJOR/MINOR` 由来。バージョン上げは master の途中で起きるので、ガイドの出力例は時期によって 4.2.0dev になったりする。本質は `-v` を見てのお楽しみ。
- 「behind 348 commits」が 3 週間で溜まる程度には master の開発ペースは速い。合宿直前に fetch する運用がよい。

## 02. autogen.sh → configure の観察

スクリプト: `02_configure.sh`。`PREFIX=$HOME/.local/share/mise/installs/ruby/master`、`--disable-install-doc`。ログは `logs/`(gitignore)。

| フェーズ | 時間 |
|---|---|
| autogen.sh | 1.8s |
| configure | 36s |

### configure summary(主要な行)

| 項目 | 値 |
|---|---|
| with thread | pthread |
| with coroutine | amd64 |
| with modular GC | no |
| enable shared libs | no |
| optflags | -O3 -fno-fast-math |
| debugflags | -ggdb3 |
| install doc | no |
| **YJIT support** | **yes** |
| **ZJIT support** | **yes** |
| RUSTC_FLAGS | `-g -C lto=thin -C opt-level=3 -C overflow-checks=on` |
| BASERUBY -v | ruby 4.0.2(system、bootstrap 用) |

warning / error はゼロ。依存検出(OpenSSL/readline/yaml/ffi/gmp)は詰まりどころになるログを出さないので、依存が足りていれば静かに通る。

### 気づき

- **ZJIT が default で有効**。これはガイド(rustc 1.58+ で YJIT が有効)より先の世界で、master には **ZJIT** という別の Rust 製 JIT が存在する(`zjit/` crate、`edition = "2024"`)。`configure.ac` の該当条件を読むと:
  - YJIT: rustc **>= 1.58.0**
  - ZJIT: rustc **>= 1.85.0**(2024 edition が必要)
  手元の rustc 1.85.0 はこの ZJIT の最低ラインに**ちょうど**乗っている。Debian 13 (trixie) 標準 apt に救われた形だが、Ubuntu 22.04 LTS 標準 apt(1.75 付近)だと YJIT は通っても ZJIT は落ちる。ガイドの「apt が古すぎたら rustup」は、**YJIT だけを指すメッセージになっているが、今は ZJIT のために rustup が必要な層が増えている**。
- `BASERUBY` に system の 4.0.2 が使われる。master のビルドには**既存の ruby が必要**(bootstrap)なので、まっさらなマシンだと apt の `ruby` も入れる必要がある。ガイドは Ruby が既に手元にある前提で書かれている。
- shared libs が `no`(static)なのが default。`--enable-shared` を指定すると `libruby.so` が別れて mkmf の C 拡張ビルド時間に効くが、default は static。ガイドは触れていない領域。
- `modular GC: no` は、外付けの alternative GC(MMTk 等)をビルド時に組み込む仕組み。合宿で触るトークなら `--with-modular-gc` を立てる配線になる。これはガイドに出てきていない。

## 03. make miniruby

スクリプト: `03_make_miniruby.sh`。`make -j4 miniruby`。`nproc=4` の VM 想定。

| 項目 | 値 |
|---|---|
| wall 時間 | 2m43s |
| user 時間 | 4m52s(並列が効いている) |
| サイズ | 74MB(`./miniruby` バイナリ) |
| 依存 .so | 8 個(`ldd miniruby`) |
| version 文字列 | `ruby 4.1.0dev (2026-04-19T07:19:51Z master f39318083e) +PRISM [x86_64-linux]` |

`make miniruby` でも `yjit.c` / `zjit.c` がコンパイルされ `libruby.a` にリンクされる。つまり **miniruby にも YJIT/ZJIT の実体コードは入っている**。

## 04. miniruby と system ruby で何ができるか

スクリプト: `04_miniruby_vs_ruby.rb`(どちらでも動く単一ファイル)。5 軸のプローブ。

| プローブ | system ruby 4.0.2 | miniruby (master) |
|---|---|---|
| `RUBY_DESCRIPTION` 末尾 | `+PRISM +GC [x86_64-linux-gnu]` | `+PRISM [x86_64-linux]` |
| `defined? Gem` | constant | constant |
| `require 'json'` | ok (2.18.0) | **LoadError** |
| `require 'openssl'` | ok | **LoadError** |
| `require 'bigdecimal'` | ok | **LoadError** |
| `require 'fileutils'` | ok | **LoadError** |
| `Encoding.list.size` | 103 | **12** |
| `defined? RubyVM::YJIT` | constant | constant |
| `defined? RubyVM::ZJIT` | constant | constant |
| `$LOAD_PATH.size` | 10 | **0** |

### 気づき

- **`$LOAD_PATH` が空**。これが「miniruby は require がほぼ通らない」の正体。stdlib のパスは `make` のもっと後段(`.rbinc` 展開 / `rbconfig.rb` 生成 / 拡張ビルド)で配られる。
- **Encoding が 12 しかない**。miniruby にあるのは `ASCII-8BIT / UTF-8 / US-ASCII / UTF-16/32-{LE,BE}` などの built-in 数件のみ。残り 90+ の encoding(`Shift_JIS`, `EUC-JP`, `ISO-8859-*` …)は `enc/*.so` を後段でビルドして register する。つまり **miniruby 単体では日本語の Shift_JIS などは open できない**。
- **`RubyVM::YJIT` / `RubyVM::ZJIT` の定数は見える**。登録自体は built-in 時点で済んでいる。実際に `.enable` して JIT コンパイルが走るかは別問題で、今回のプローブでは踏み込んでいない。
- **`+GC` flag が miniruby 側に無い**。system ruby 4.0.2(Debian パッケージ)は modular GC framework 有効でビルドされているが、こちらは `configure: modular GC: no` を選んだためマーカーが落ちている。`+GC` は「モジュラ GC を差し替えられる世界」のサイン。
- miniruby は「構文を食って評価できる」最小単位の ruby であって、「rubygems も stdlib も無い Ruby 処理系」。あとから全部配られる。ブートストラップの順番を身体で知る入口として、`make miniruby` だけ先に走らせるのはすごく良い学習材料。

## 05. make(フルビルド)

スクリプト: `05_make_full.sh`。miniruby の後段、拡張 (`enc/*`, `ext/*`) と stdlib を組んで最終 `ruby` を作る。

| 項目 | 値 |
|---|---|
| wall 時間 | 1m37s(miniruby 後) |
| user 時間 | 2m22s |
| ruby サイズ | 74MB(miniruby とほぼ同じ) |
| 依存 .so | 8 個 |
| enc/*.so | **61 個** |
| 拡張 .so 合計 | **161 個**(enc 61 + 非 enc 100) |

`ruby` バイナリ自体は miniruby とサイズがほぼ変わらない。差は `.ext/**/*.so`(合計 **161 個**)に出る。非 enc 100 個のうち `openssl.so` / `digest.so` / `date_core.so` / `bigdecimal.so` 等が stdlib の C 拡張、残りは bug/test 用や内部用 helper。

### ビルドツリーの ./ruby を直に使うと詰まる

フル `make` 後でも `~/repos/ruby/ruby` を直接実行すると:

```
`RubyGems' were not loaded.
`error_highlight' was not loaded.
`did_you_mean' was not loaded.
`syntax_suggest' was not loaded.
```

と 4 連発の警告が出て、`require 'json'` すら **LoadError**。`$LOAD_PATH` は **install 先の PREFIX**(まだ存在しないパス)を指しているため、stdlib を一切探せない。
**ビルドツリーの `./ruby` は `make install` 前は使い物にならない**のが原則で、合宿で master を触るなら install まで一気にやる。

## 06. make install

スクリプト: `06_make_install.sh`。PREFIX=`$HOME/.local/share/mise/installs/ruby/master`。

| 項目 | 値 |
|---|---|
| wall 時間 | 32s |
| bin/ のコマンド数 | 14(install 直後) |
| lib/ruby 以下 *.rb | 1,393 |
| lib/ruby 以下 *.so | 94 |
| gems/ 数 | 81 |
| 総サイズ | **340MB**(`--disable-install-doc` でも) |

インストール後にプローブをかけ直すと、すべてグリーン(json 2.19.4, openssl, bigdecimal, fileutils OK、Encoding 103 件、$LOAD_PATH 10 件、警告ゼロ)。これが「本来の ruby」。

### 詰まりどころ: bundled gem の取りこぼし

`make install` の summary に:

```
skipped bundled gems:
    debug-1.11.1.gem   extensions not found or build failed debug-1.11.1
    rbs-4.0.2.gem      extensions not found or build failed rbs-4.0.2
    win32ole-1.9.3.gem extensions not found or build failed win32ole-1.9.3
```

`win32ole` は Linux で常に落ちるので無視でよい。**問題は `rbs` と `debug`**。bin/ から `rdbg` と `rbs` が欠落し、合宿で TypeProf や Debug を触る人は入口で詰まる。

回避策は自明で、**`gem install` で .gem ファイルから入れ直せば通る**:

```sh
gem install $HOME/repos/ruby/gems/debug-1.11.1.gem
gem install $HOME/repos/ruby/gems/rbs-4.0.2.gem
```

手元ではこれで `rdbg 1.11.1` / `rbs 4.0.2` が bin/ に増えた。
`make install` 中は「自分自身を install しきっていない ruby」で C 拡張をビルドしようとして落ちているので、install 完了後にリトライすれば問題なく通る、というメンタルモデルで説明できる(たぶん)。

### 気づき

- `./ruby -v` から miniruby と同じく `+PRISM [x86_64-linux]`。`+GC` / `+YJIT` / `+ZJIT` のようなマーカーは出ない。system の Debian 4.0.2 は `+PRISM +GC` と出ていたので、`+GC` マーカーは modular GC framework 有効化時(`--enable-shared` との組み合わせ?)限定かもしれない。
- `lib/ruby/4.1.0+1/x86_64-linux` のようにバージョンディレクトリに `+1` が付いている。これは ABI suffix(`include/ruby/internal/abi.h`)で、master の途中で ABI が割れた時の弁。stable リリースには付かない。
