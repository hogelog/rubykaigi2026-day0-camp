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
