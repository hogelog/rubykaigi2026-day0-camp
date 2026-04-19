# themes/build-ruby.md への学習者フィードバック

合宿参加者が **Debian 13 (trixie)** で 2026-04-19 時点の ruby/ruby master を実ビルド
(HEAD `f39318083e`、`ruby 4.1.0dev`)した観察ログに基づくフィードバック。

## 良かった点

- **PREFIX を `$HOME/.local/share/mise/installs/ruby/<version>` に切る**指示が効いた。この layout は `mise install` を別途走らせなくても、単に `make install` で配ったツリーを mise がそのまま「インストール済み」として拾ってくれる(`mise list ruby` → `ruby master`、`mise exec ruby@master -- ruby -v` が通る)。rbenv 派に配慮した後段(`ln -s ... ruby-master`)もあって、切替ツール問わず動く書き方になっている。
- 「master はどう転ぶか分からないので常用 Ruby に据えるのはチャレンジング、触りたいときだけシェルで切り替える」のトーンが正しい。初心者に「default ruby を master に」と迫る文面ではないのは大事。
- 「追加で試してみたいこと」に **`gh pr checkout`** と **`make miniruby`** と **debug ビルド** が並んでいるのは、合宿の発表を追いかけるフックとして良い選定。特に `make miniruby` は「bootstrap ruby → 拡張/stdlib → ruby」の段階を身体で学べる最短コース。

## もう少しあると嬉しかった点(本文に足したいレベル)

### 1. ZJIT の話が丸ごと抜けている

**発生状況**: 2026-04 時点の ruby/ruby master では `configure` の summary に `YJIT support: yes` と並んで **`ZJIT support: yes`** が出る。`zjit/` crate が追加されており、`--zjit` フラグで method-based JIT が動く。YJIT より速い局面もあるくらい実用段階。

**こういう 1 行があれば救われる**: 「今の master は `--yjit` に加えて `--zjit` でもう一本別の JIT が動く」「ZJIT は rustc 1.85+(2024 edition 必要)なので、Ubuntu 22.04 LTS 標準 apt の rustc では ZJIT が落ちる。その場合は rustup」。今のガイドの `rustc 1.58 以上` は YJIT 向けの記述で、ZJIT には追いついていない。

### 2. ビルドツリーの `./ruby` は `make install` 前は使えない

**発生状況**: `make` フル完了後、`~/repos/ruby/ruby` を直接叩くと `RubyGems' were not loaded.` が出たあと `require 'json'` すら LoadError になる。`$LOAD_PATH` は **install 先の PREFIX**(まだ存在しないパス)を指しているため、stdlib を一切探せない。初見で「ビルドは通ったのに何もできない」と勘違いしがち。

**こういう 1 行があれば救われる**: 「ビルドツリーの `./ruby` は `rbconfig.rb` が install 先の PREFIX を焼き込んでいる。試用するのは `make install` 後の `$PREFIX/bin/ruby` のほう。ビルドツリーで動かしたいなら `-I` で stdlib パスを手で足す」。

### 3. bundled gem 取りこぼし(`debug` / `rbs`)の対処

**発生状況**: `make install` の summary に:

```
skipped bundled gems:
    debug-1.11.1.gem      extensions not found or build failed debug-1.11.1
    rbs-4.0.2.gem         extensions not found or build failed rbs-4.0.2
    win32ole-1.9.3.gem    extensions not found or build failed win32ole-1.9.3
```

が出て、**`rdbg` と `rbs` が bin/ から欠落する**。合宿で TypeProf や Debug のトークを追いかける参加者が、最初の `rdbg --version` でいきなり詰まる。手元では `gem install $HOME/repos/ruby/gems/debug-1.11.1.gem` と `rbs-4.0.2.gem` を install し直すと通った。

**こういう 1 行があれば救われる**: 「`make install` 中に `debug` / `rbs` が `extensions not found or build failed` でスキップされることがある。install が終わったあと `gem install <source>/gems/<gem>-*.gem` で入れ直せば通る」— できれば「よくあるハマりどころ」に追加。

### 4. `mise exec` / `mise.toml` の方が「`mise shell`」より当てになる

**発生状況**: ガイドは `mise shell ruby@master` を勧めているが、mise 未 activate の素の shell からは `mise is not activated in this shell session` で失敗する。一方 `mise exec ruby@master -- ruby -v` と、`mise.toml` に `ruby = "master"` を書いて `mise trust` した上で `cd` する経路は **どちらも activate 不要で通る**。

**こういう 1 行があれば救われる**: 「shell から直接叩くなら `mise exec ruby@master -- <cmd>`、プロジェクトで切り替えるなら `mise.toml` に `ruby = "master"`(初回は `mise trust` が要る)。`mise shell` は `.bashrc` などで `mise activate` してある shell からしか効かない」。

### 5. 「miniruby だけ先にビルドして触ってみる」の小さなレシピ

**発生状況**: ガイドの「追加で試してみたいこと」に「`miniruby` と `ruby` の違いを体感する(`make miniruby` だけやってみる)」と 1 行ある。実際にやってみると `$LOAD_PATH` が空 / Encoding が 12 件だけ / `require 'json'` が全滅 という、**stdlib 抜きの ruby** が姿を見せる。体感としてすごく面白いのに、ガイドには誘導があるだけで「何を見れば違いが分かるか」がない。

**こういう 1 行があれば救われる**:「`make miniruby` 後に `./miniruby -e 'puts \$LOAD_PATH.size'` と `./miniruby -e 'puts Encoding.list.size'` を叩くと、それぞれ 0 と 12 が出る(install 済みの ruby は 10 と 103)。これが『rubygems も stdlib も配られる前の ruby』の姿」。

## 上級への入り口の設計

ガイド末尾の「追加で試してみたいこと」は着地が漠然としているので、最小スニペットを 1 行添えるだけで大きく敷居が下がる:

- `make test-all` / `make test-spec` → これは時間がかかる。`./ruby test/runner.rb <file> -n "/pattern/"` で **部分テスト**を流す書き方を先に挙げると、PR を追いかける人が即座に使える(fib(35) を 0.007s で通せる世界)。
- `gh pr checkout <N>` → 実演して気づいたが、checkout 後は incremental `make -j` で 10〜15 秒で終わる(C 変更ゼロの PR なら `Nothing to be done for 'note'.`)。**ruby 側はどの PR でも重ビルドにはならない**の一文があれば一歩踏み出せる。
- `./ruby -v` に **branch 名と HEAD SHA** が埋まる仕様に触れる。PR を試している間に誤って system ruby で検証するのを防げる地味に大事な挙動。
- debug ビルド: `configure --with-debug-cflags='-O0 -g3'` の例がガイドに書いてある。**ここから `gdb ./miniruby` で `rb_vm_exec` に brk を置く**、のような gdb 1 コマンド目まで書けると、「C 側を覗く日」のハードルが激減する。

## ガイドのメンタルモデルが古い箇所

- **「rustc 1.58 以上」は YJIT 単独の要件**。2026-04 の master では ZJIT が default 有効で、こちらは rustc 1.85+(2024 edition)。ガイドは `rustc 1.58 以上` で止まっていて、ZJIT は視界の外にある。`configure.ac` を grep すると両方の条件がコメント付きで並んでいる。
- **modular GC** (`--with-modular-gc`) が default 無効の扱いで出てこない。`ruby -v` の `+GC` マーカーは modular GC framework が有効なときのしるしで、`make install` したビルドは `+GC` が付かない(system の Debian 4.0.2 には付いている)。MMTk など外付け GC のトークを追うなら `--with-modular-gc` を立てるところから。
- **`+PRISM`**(デフォルトパーサが Prism)は今はあまりに当たり前なので特筆不要だが、参加者によっては新鮮かもしれない。

## 道具の限界の明示

本テーマで使った道具(dpkg-query / ldd / `make -j` / `RubyVM::YJIT.runtime_stats`)で**見えないこと**:

- `RubyVM::YJIT.runtime_stats` は **`--yjit-stats` フラグ無しだと `nil`**。`RubyVM::ZJIT.stats` は `--zjit-stats` 無しでも `compile_time_ns` 等の基本値が返る(YJIT と API 粒度が違う)。
- `--yjit-stats` / `--zjit-stats-quiet` は **instrumentation で ~5x 遅くなる**。速度比較とカウンタ観察は別の run で行う。fib(35) で interp 0.808s / YJIT (stats 付) 3.86s というブレ方になる。
- `make install` の summary は **最後の 5 行くらいしか見ない**運用だと `debug` / `rbs` のスキップに気付きにくい。ログは全量眺めるか `grep -i skip` をクセにする。
- 計測の入口としては `RubyVM::YJIT.insns_compiled(method(:fib))` が iseq 単位で「何命令 JIT 化されたか」を教えてくれる(master では引数必須)。次の道具は `RubyVM::YJIT.disasm(method)` で実際の x86 コードを見ること。
