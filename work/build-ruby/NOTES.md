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
