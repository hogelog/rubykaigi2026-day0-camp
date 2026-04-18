# String — Ruby の文字列の内側を覗く

## なぜ触るのか

`String` は Ruby で最も使うクラスの一つだが、その中身(エンコーディング、メモリレイアウト、凍結、共有、符号化変換)を意識することは普段ほぼない。

近年の Ruby は文字列周りが特に熱い領域で、RubyKaigi では毎年のように Encoding、M17N、frozen string literal、RString のレイアウト変更、RJIT / YJIT 最適化などが話題になる。処理系レベルで何が起きているかを一度でも手で触っておくと、本編トークの解像度が跳ね上がる。

## 触って分かると嬉しいこと

- `Encoding` とは何か、`force_encoding` / `encode` の違い
- `String#bytesize` と `#length` がずれる理由
- frozen string literal の効果(メモリ・性能)
- `String#+@` / `#-@` / `String#dup` の挙動の違い
- C レベルでの `RString` 構造(embedded / heap、`rb_str_new` 系 API)

## 取り組みアイデア(難易度順)

### 入門

- 日本語文字列で `bytes`, `chars`, `codepoints`, `grapheme_clusters` の違いを比較する
- 絵文字(👨‍👩‍👧‍👦 のような ZWJ 合字)で `length` がどう見えるか調べる
- frozen string literal あり / なしで `ObjectSpace.count_objects` を比べる

### 中級

- `Encoding::Converter` を使って複雑な変換(Shift_JIS ↔ UTF-8、BOM 付き UTF-16 など)を書く
- `String#==` と `#eql?` と `#hash` の関係を実験で確かめる
- ベンチマークで `"foo" + "bar"` と `"foo" << "bar"` と `String#+ "bar"` などの差を見る

### 上級

- ruby/ruby の `string.c` を読み、Embedded String と Heap String の境界を自分の目で確かめる(`ObjectSpace.memsize_of` 活用)
- `RString` の構造を `gdb` や `objdump` で覗く
- Encoding を自作する実験(`Encoding::Converter` のカスタム・ASCII-8BIT 扱い)
- `String#+@`(unfrozen copy)と Copy-on-Write 的な挙動を観察する

## 予想される詰まりどころ

- `ASCII-8BIT` と `UTF-8` の混在で `Encoding::CompatibilityError`
- frozen 由来の `FrozenError`(特に文字列リテラル由来)
- ベンチマークを取るときの GC ノイズ(`GC.disable` / warmup)
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
- frozen の有無で速度/メモリがどれだけ違うかを数字で見せる
- C の構造体のポンチ絵を書いて、embedded / heap の切替境界を図にすると強い
