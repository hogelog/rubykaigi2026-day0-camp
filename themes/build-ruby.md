# ruby/ruby master をビルドして自分のデフォルト ruby にしてみる

## なぜやるのか

RubyKaigi で話される機能の多くは、リリース済の Ruby ではまだ試せない master ブランチ上の変更だったりする。自分の手で master をビルドできるようになっておくと、

- 発表で触れられた PR を手元でチェックアウトして試せる
- C 拡張や処理系内部に PR を投げる第一歩になる
- `miniruby` と `ruby` の違いなど、ビルドプロセスそのものからも学べる

合宿のメイン成果物というよりは、**どのテーマを選んだ人にも効いてくる基礎装備**。可能なら前日までにやっておくと当日が捗る。

## ざっくり手順(macOS / Linux)

以下はあくまでざっくりの流れ。最新手順は公式の `doc/contributing/building_ruby.md` を参照。

### 1. 依存ツールを入れる

macOS(Homebrew):

```sh
brew install openssl@3 readline libyaml gmp autoconf bison rust
```

Ubuntu / Debian:

```sh
sudo apt-get install -y build-essential autoconf bison \
  libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev libgmp-dev \
  rustc
```

`rustc` は YJIT / ZJIT を有効にしたビルドをするのに必要。YJIT は 1.58 以上、ZJIT は 1.85 以上が要る(ZJIT は Rust 2024 edition を使っているため)。どちらも入れておけば configure が勝手に両方有効化し、summary に `YJIT support: yes` / `ZJIT support: yes` と並ぶ。apt 版 `rustc` が ZJIT 側に届かない distro では [rustup](https://rustup.rs/) を使う。

### 2. ソースを clone する

```sh
git clone https://github.com/ruby/ruby.git
cd ruby
```

### 3. configure & build

インストール先を分けておくのがおすすめ。STORES 社内では mise を Ruby を含む開発ツールの基本にしているので、`mise` の管理ディレクトリ配下に prefix を切ると後段で扱いやすい。

mise を使う場合(推奨):

```sh
PREFIX="$HOME/.local/share/mise/installs/ruby/master"
./autogen.sh
./configure --prefix="$PREFIX" --disable-install-doc
make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu)
make install
```

rbenv / chruby / asdf を使っている場合は、それぞれの慣習に合わせて `~/.rubies/ruby-master` のようなパスを prefix に指定する。

### 4. ビルドした ruby を使う

master ビルドはどう転ぶか分からない代物なので、グローバルの常用 Ruby に据えるのはかなりチャレンジング。普段は安定版を使い、「触りたいときだけシェルで切り替える」くらいがちょうどよい。

mise の場合(シェルだけで一時的に使う):

```sh
mise shell ruby@master
ruby -v    # => ruby 4.1.0dev (...) ...
```

実験用ディレクトリだけで使うなら `mise.toml` に `ruby = "master"` を書いておくとそのディレクトリ配下でのみ切り替わる。

rbenv の場合(例):

```sh
ln -s $HOME/.rubies/ruby-master $(rbenv root)/versions/master
rbenv rehash
rbenv shell master
ruby -v
```

## よくあるハマりどころ

- **OpenSSL が見つからない** — macOS は `--with-openssl-dir=$(brew --prefix openssl@3)` を configure に付ける
- **bison のバージョン違い** — macOS 同梱の bison では通らない。Homebrew 版を PATH に
- **ccache が邪魔して再ビルドが変** — 疑わしいときは `make clean` から
- **mise / rbenv の shim が古い ruby を指している** — `mise reshim` / `rbenv rehash` を忘れずに
- **ビルドツリーの `./ruby` を直叩きすると動かない** — `$LOAD_PATH` にインストール先の prefix が焼き込まれていて、`make install` 前はその場所が存在しない。`` `RubyGems' were not loaded.`` の警告と共に `require` が軒並み落ちる。試すのは `$PREFIX/bin/ruby` のほう
- **`make install` で `debug` / `rbs` が skip される** — summary に `extensions not found or build failed debug-*.gem` / `rbs-*.gem` と出て、`rdbg` / `rbs` コマンドが bin/ から欠ける。install 完了後に `gem install <ruby-src>/gems/debug-*.gem` と `rbs-*.gem` を叩き直すと通る(インストール途中の ruby で C 拡張を組もうとして失敗している)

## 追加で試してみたいこと

- `make test-all` / `make test-spec` を走らせる
- `miniruby` と `ruby` の違いを体感する(`make miniruby` だけやってみる)。`./miniruby -e 'puts $LOAD_PATH.size'` が `0`、`./miniruby -e 'puts Encoding.list.size'` が `12` を返す(インストール済みの ruby はそれぞれ `10` と `103`)。stdlib も拡張 encoding もまだ配られていない、「ruby 本体を組み上げるための最小 ruby」の姿が 2 行で見える
- 気になる PR を `gh pr checkout` で持ってきてビルドして差分の挙動を確認する
- `configure --with-debug-cflags='-O0 -g3'` でデバッグビルドして `lldb` / `gdb` で追う

## 参考リンク

- Building Ruby(公式): https://github.com/ruby/ruby/blob/master/doc/contributing/building_ruby.md
- ruby/ruby: https://github.com/ruby/ruby
- mise: https://mise.jdx.dev/
- chruby: https://github.com/postmodern/chruby
- rbenv: https://github.com/rbenv/rbenv
- ruby-build: https://github.com/rbenv/ruby-build
