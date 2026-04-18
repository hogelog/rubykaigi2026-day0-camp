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
brew install openssl@3 readline libyaml gmp autoconf bison
```

Ubuntu / Debian:

```sh
sudo apt-get install -y build-essential autoconf bison \
  libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev libgmp-dev
```

### 2. ソースを clone する

```sh
git clone https://github.com/ruby/ruby.git
cd ruby
```

### 3. configure & build

`~/.rubies/ruby-master` のようにインストール先を分けておくのがおすすめ(chruby / ruby-install / rbenv などと併用しやすい)。

```sh
./autogen.sh
./configure --prefix=$HOME/.rubies/ruby-master --disable-install-doc
make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu)
make install
```

### 4. デフォルト ruby として使う

rbenv / chruby / asdf など、普段使っているバージョンマネージャの流儀に合わせて登録する。

rbenv の場合(例):

```sh
ln -s $HOME/.rubies/ruby-master $(rbenv root)/versions/master
rbenv rehash
rbenv shell master
ruby -v    # => ruby 3.x.0dev (...) ...
```

## よくあるハマりどころ

- **OpenSSL が見つからない** — macOS は `--with-openssl-dir=$(brew --prefix openssl@3)` を configure に付ける
- **bison のバージョン違い** — macOS 同梱の bison では通らない。Homebrew 版を PATH に
- **ccache が邪魔して再ビルドが変** — 疑わしいときは `make clean` から
- **rbenv の shim が古い ruby を指している** — `rbenv rehash` を忘れずに

## 追加で試してみたいこと

- `make test-all` / `make test-spec` を走らせる
- `miniruby` と `ruby` の違いを体感する(`make miniruby` だけやってみる)
- 気になる PR を `gh pr checkout` で持ってきてビルドして差分の挙動を確認する
- `configure --with-debug-cflags='-O0 -g3'` でデバッグビルドして `lldb` / `gdb` で追う

## 参考リンク

- Building Ruby(公式): https://github.com/ruby/ruby/blob/master/doc/contributing/building_ruby.md
- ruby/ruby: https://github.com/ruby/ruby
- chruby: https://github.com/postmodern/chruby
- rbenv: https://github.com/rbenv/rbenv
- ruby-build: https://github.com/rbenv/ruby-build
