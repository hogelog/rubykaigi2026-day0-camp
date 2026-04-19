# themes/string.md への学習者フィードバック

Ruby 4.0.2 で入門・中級を一通り手を動かしてみた結果、ガイドに対して
感じたことのまとめ。「合宿の参加者目線で読みやすくするための改善提案」
として残す。

## よかった点

- 「触って分かると嬉しいこと」が**手を動かす前の to-do リスト**として機能していた。`bytesize` と `length` のズレ、frozen string literal の効果、`+@` / `-@` の違い、など項目が十分具体的。
- 入門 → 中級 → 上級の段階構成が自然で、前の実験で得た観察が次の実験の土台になる並びだった。
- 「予想される詰まりどころ」を先に読んでおいたことで `Encoding::CompatibilityError` 的な失敗で慌てずに済んだ。先回りの注意書きは強い。
- `string.c` / `include/ruby/internal/core/rstring.h` への直リンクが、上級に進むときの迷いを減らしてくれた。

## もう少しあると嬉しかった点

以下は「初見で詰まった」「書いてあれば 15 分節約できた」系の具体フィードバック。

### 1. 「入門」の最初の一歩に使えるワンライナーが欲しい

「bytes, chars, codepoints, grapheme_clusters の違いを比較する」の例として、`"日本語👨‍👩‍👧‍👦".each_char.to_a` のような **3 秒で走る ruby -e** を貼っておくと、エディタ開かずにまず体感できる。手元だと ZWJ 家族絵文字の `length == 7, grapheme_clusters == 1` のインパクトが一番刺さった。

### 2. frozen string literal の「式展開では効かない」注意書き

「frozen_string_literal あり / なしで `ObjectSpace.count_objects` を比べる」までは書いてあるが、`"hello #{name}"` のように式展開を含む文字列リテラルは frozen: true でも毎回新しく作られる。これは「frozen を入れたのにアロケーションが減らない」系の FAQ の温床。**1 行注記があるだけで救われる人が多そう**。

### 3. `eql?` と encoding と Hash キー

`==` / `eql?` / `hash` の項目は書かれているが、**ASCII-only 文字列だと encoding をまたいでも `eql?` / `hash` が一致する**という実用上よくハマるところが明記されていない。「UTF-8 の Hash に US-ASCII なキーでアクセス → 引ける、Shift_JIS の `"日本"` キーでアクセス → 引けない」あたりは 1 行でも書いておくと、Rails のリクエスト処理などで役立つ。

### 4. NFC / NFD の正規化問題

絵文字 ZWJ については書かれているが、より罠にハマりやすいのは NFC (`U+00E9`) と NFD (`U+0065 U+0301`) の `é` で **見た目同じなのに `==` が false**。ユーザ入力由来の文字列を Hash キーや DB の一意制約に使う時に痛い目に遭う。`String#unicode_normalize` の存在を一行添えておきたい。

### 5. ベンチの注意「warmup」と「Ruby のバージョン」

「ベンチマークを取るときの GC ノイズ(`GC.disable` / warmup)」は書かれているが、**warmup の具体例**(最初にダミーで数回回す)まで書いてあると初学者が再現しやすい。また Ruby のバージョンが違うと `+` 周りは最適化が入ったり抜けたりするので、**計測時に `RUBY_DESCRIPTION` を必ず添える**のをテンプレ化しておくと良い。

### 6. `benchmark-ips` 前提になってない選び方

Ruby 4.0 同梱の stdlib は `benchmark` のみで、`benchmark/ips` は gem 追加が必要。ガイドの例が `benchmark-ips` 前提だとインストールでつまずくので、**stdlib の `Benchmark.realtime` だけで完結するサンプル**か、`gem install benchmark-ips` の一行を推奨リストに足すと親切。

### 7. Ruby 4.0 版の `+@` / `-@` と string interning

「`String#+@` / `#-@` / `String#dup` の挙動の違い」は触れられているけど、**`-"literal"` と `-"literal"` が同じ `object_id`**(共有される)まで観察できると interning の概念がバチっと掴める。Ruby 3.3 以降の挙動なので、4.0 前提の合宿では前面に出して良さそう。

## 上級への入り口の設計

- 「ruby/ruby の `string.c` を読み、Embedded String と Heap String の境界を自分の目で確かめる」は重い課題だが、**先に `ObjectSpace.memsize_of("a" * N)` を N を変えて並べて見る**だけでも境界の存在は掴める。入口としてこの ruby コード 1 本を紹介する段落があると、C ソースに行く前の助走になる。
- `include/ruby/internal/core/rstring.h` の `RSTRING_EMBED_LEN_MAX` 相当値(64bit 系で 23 あたり)を見る、という具体指差しをすると、読者が「この定数を探せばいい」と分かる。

### 8. 「embedded / heap」の 2 値モデルを VWA 前提で更新してほしい

実際に `ObjectSpace.memsize_of` を並べてみると、Ruby 4.0 では **embedded と heap の二値ではなく、`40 / 80 / 160 / 320 / 640 bytes` といった複数段階の GC サイズクラス + 大きい文字列は `malloc`**、という **3 層以上**の姿が見える。最初のジャンプも古典的な 23 bytes ではなく **12〜16 bytes 付近**。

現行ガイドは「embedded / heap」という古典モデルで書かれているので、以下の補足があるとちょうど RubyKaigi 本編で Variable Width Allocation / RString 最適化のトークを聴く前座になる:

- Ruby 3.x〜4.0 にかけて導入された **Variable Width Allocation (VWA)** の一行紹介
- 「embedded / heap の境界」ではなく「**埋め込み可能な最大長は GC のサイズクラスに依存**する(最近の Ruby では複数段階ある)」という記述
- `ObjectSpace.memsize_of` で N を振って size class の階段が見える、という実験の誘導
- peterzhu2118 の VWA トークへのリンクをもう少し前面に

### 9. `ObjectSpace.memsize_of` の限界も明記すると親切

`dup` / `-@` / `+@` の違いや、**部分文字列の共有バッファ**(substring sharing)は `memsize_of` 単体では判別できなかった(値が同じになる)。そこを見たければ `ObjectSpace.dump` / `ObjectSpace.dump_all` で JSON を見るか、C 側の `rb_str_shared_p` まで踏み込む必要がある、という **「memsize_of で見えないこと」の注記**があると、読者が次の道具に素直に移れる。

## まとめ

全体としてよくできたガイド。**入門の最初に「走らせて驚く 3 分ネタ」を貼る**、**中級の「式展開/エンコーディング/NFC-NFD」の罠を 1 文ずつ補強する**、**ベンチの再現手順(warmup・バージョン表記)を明文化する**、この 3 点を足すと、初見の参加者の体験が滑らかになりそう。
