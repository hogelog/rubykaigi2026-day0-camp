# String — Ruby の文字列の内側を覗く

## なぜ触るのか

`String` は Ruby で最も使うクラスの一つだが、その中身(エンコーディング、メモリレイアウト、凍結、共有、符号化変換)を意識することは普段ほぼない。

近年の Ruby は文字列周りが特に熱い領域で、RubyKaigi では毎年のように Encoding、M17N、frozen string literal、RString のレイアウト変更、RJIT / YJIT 最適化などが話題になる。処理系レベルで何が起きているかを一度でも手で触っておくと、本編トークの解像度が跳ね上がる。

## 触って分かると嬉しいこと

- `Encoding` とは何か、`force_encoding` / `encode` の違い
- `String#bytesize` と `#length` がずれる理由、「人間目線の 1 文字」としての `grapheme_clusters`
- frozen string literal の効果(メモリ・性能)、そして**式展開があると効かない**こと
- `String#+@` / `#-@` / `String#dup` の挙動の違い、`-"..."` による string interning
- C レベルでの `RString` 構造(Ruby 3.x 以降の **Variable Width Allocation** による段階的サイズクラス、embedded / heap、`rb_str_new` 系 API)

## 取り組みアイデア(難易度順)

### 入門

- まず 3 秒で驚くワンライナー: `ruby -e 'p "👨‍👩‍👧‍👦".length, "👨‍👩‍👧‍👦".grapheme_clusters.size'` → `7` と `1` が出る。「文字数」の定義がいくつあるかを一瞬で体感できる
- 日本語文字列で `bytes`, `chars`, `codepoints`, `grapheme_clusters` の違いを比較する
- 絵文字(👨‍👩‍👧‍👦 のような ZWJ 合字)で `length` がどう見えるか調べる
- NFC (`"\u00E9"`) と NFD (`"e\u0301"`) の `é` は**見た目同じなのに `==` が false**。Hash キー・一意制約・比較に効いてくる。`String#unicode_normalize(:nfc)` で吸収する
- frozen string literal あり / なしで `ObjectSpace.count_objects` を比べる。**式展開 (`"hello #{name}"`) を含むリテラルは `frozen: true` でも毎回新しく作られる**点も確かめる
- `-"literal"` と `-"literal"` が `equal?` で真(同じ `object_id`)になる interning を観察する

### 中級

- `Encoding::Converter` を使って複雑な変換(Shift_JIS ↔ UTF-8、BOM 付き UTF-16 など)を書く。UTF-16 は BOM 付き BE、UTF-16BE / UTF-16LE は BOM 無しでエンディアン固定、という違いを手でバイト列を見て確認する
- `String#==` と `#eql?` と `#hash` の関係を実験で確かめる。特に **ASCII-only な文字列は encoding が違っても `eql?` / `hash` が一致**する(UTF-8 Hash に US-ASCII キーでアクセスできる)が、非 ASCII だと encoding 違いは別値扱いになることまで
- ベンチマークで `"foo" + "bar"` と `"foo" << "bar"` と `Array#join` などの差を見る。**warmup を入れ、`RUBY_DESCRIPTION` を必ず結果に併記**する。`+` / `+=` はループで繋ぐと O(N²) になり、`<<` や `join` との差が 3 桁出ることがある。`benchmark-ips` を入れていなくても stdlib の `Benchmark.realtime` で十分実験できる

### 上級

- `ObjectSpace.memsize_of("a" * N)` を N を変えて並べ、RString のメモリ階層を観察する。Ruby 3.x 以降は **Variable Width Allocation (VWA)** により、**embedded / heap の 2 値ではなく `40 / 80 / 160 / 320 / 640 bytes …` といった複数段階のサイズクラス + 大きな文字列で malloc** という 3 層以上の構造になっている。古典的な `RSTRING_EMBED_LEN_MAX == 23` だけを持って臨むと期待と違う結果になる
- ruby/ruby の `string.c` と `include/ruby/internal/core/rstring.h` を読み、上の階段が何によって決まっているかをコード側で追う
- `ObjectSpace.memsize_of` で**見えないこと**(共有バッファの有無、interning されているかなど)は `ObjectSpace.dump` / `dump_all` の JSON や C 側の `rb_str_shared_p` で追う
- `RString` の構造を `gdb` や `objdump` で覗く
- Encoding を自作する実験(`Encoding::Converter` のカスタム・ASCII-8BIT 扱い)
- `String#+@`(unfrozen copy)と Copy-on-Write 的な挙動を観察する

## 予想される詰まりどころ

- `ASCII-8BIT` と `UTF-8` の混在で `Encoding::CompatibilityError`
- `force_encoding` と `encode` の混同。前者はラベル貼り替えだけ、後者はバイト書き換え。ASCII-8BIT → UTF-8 の `encode` は**変換テーブルが無く失敗する**(バイトをそのまま UTF-8 として解釈したいなら `force_encoding`)
- frozen 由来の `FrozenError`(特に文字列リテラル由来)
- ベンチマークを取るときの GC ノイズ(`GC.disable` / warmup)。**バージョン差で最適化が変わる**ので `RUBY_DESCRIPTION` を必ず結果に添える
- `ObjectSpace.memsize_of` 単体では embedded / heap / 共有バッファの細部までは分からない。深追いするなら `ObjectSpace.dump` か C 側へ
- ruby/ruby 本体を読むのは最初しんどい。`string.c` の目次的コメントを先に眺めるのがコツ

## 参考リンク

Ruby の文字列は複数のコミッタが関わる領域。STORES では ima1zumi がエンコーディング・文字幅計算の実装や発表を継続しており、ko1 は RString レイアウト・GC と絡むメモリ最適化を担当している。

- Ruby 公式ドキュメント `String`: https://docs.ruby-lang.org/ja/latest/class/String.html
- Ruby 公式ドキュメント `Encoding`: https://docs.ruby-lang.org/ja/latest/class/Encoding.html
- ruby/ruby `string.c`: https://github.com/ruby/ruby/blob/master/string.c
- ruby/ruby `include/ruby/internal/core/rstring.h`: https://github.com/ruby/ruby/blob/master/include/ruby/internal/core/rstring.h
- **ima1zumi の RubyKaigi 発表**: https://rubykaigi.org/2025/presentations/ima1zumi.html など。Encoding / 文字幅まわりの最新動向
- **ko1 の RubyKaigi 発表**: https://rubykaigi.org/2025/presentations/ko1.html など。RString / GC / 並行性の観点
- 歴史的経緯としては成瀬さん(M17N)や peterzhu2118 さん(Variable Width Allocation)の発表も合わせて追うとよい

## アウトプットのヒント

- 「この 1 文字がメモリ何バイトを使っているか」をビジュアル化する
- frozen の有無で速度/メモリがどれだけ違うかを数字で見せる(`RUBY_DESCRIPTION` を必ず併記)
- RString のレイアウト図を描く。Ruby 3.x 以降は VWA のサイズクラスと絡むので、**どのバージョンの Ruby を前提にしているか**も書き添えると強い
