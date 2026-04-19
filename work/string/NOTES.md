# String 内部学習メモ

RubyKaigi 2026 Day 0 合宿の予習として、Ruby の `String` を処理系寄りに触った記録。

- Ruby: `ruby 4.0.2 (2026-03-17 revision d3da9fec82) +PRISM +GC [x86_64-linux-gnu]`
- 環境: Linux 6.12.43+deb13-amd64

## 01. bytes / chars / codepoints / grapheme_clusters

`work/string/01_units.rb` 実行結果から、文字列の「数え方」は少なくとも 4 種類あることが一発で分かる。

| 文字列 | bytesize | length | codepoints | grapheme_clusters |
| --- | --- | --- | --- | --- |
| `"hello"` | 5 | 5 | 5 | 5 |
| `"日本語"` | 9 | 3 | 3 | 3 |
| `"😀"` | 4 | 1 | 1 | 1 |
| `"👨‍👩‍👧‍👦"` (ZWJ family) | **25** | **7** | **7** | **1** |
| `"👋🏽"` (skin tone) | 8 | 2 | 2 | 1 |
| `"é"` NFC (`U+00E9`) | 2 | 1 | 1 | 1 |
| `"é"` NFD (`U+0065 U+0301`) | 3 | 2 | 2 | 1 |

気づき:
- `length` は **コードポイント数** であって、人間が見る「文字数」ではない。ZWJ 家族絵文字は 1 グラフェムだが `length == 7`。
- 「人間目線の 1 文字」が欲しいなら `String#grapheme_clusters.size`。UI の文字数制限などはこちらを使うべき。
- NFC と NFD で `==` は `false` になる(後述)。Unicode 正規化しないと一致判定がズレる。
- Ruby は内部で UTF-8(当該文字列は `encoding=UTF-8`)。コードポイント →  UTF-8 バイト列は可変長(1〜4 bytes)。

## 02. frozen string literal と ObjectSpace

`1_000.times do "hello world" end` を回して `ObjectSpace.count_objects[:T_STRING]` の増分と、全ループの `object_id` がいくつユニークかを数えた。

| マジックコメント | `.frozen?` | T_STRING 増分 | ユニーク object_id 数 |
| --- | --- | --- | --- |
| `frozen_string_literal: true` | `true` | **0** | **1** |
| `frozen_string_literal: false` | `false` | 1000 | 1000 |
| `true` + 式展開 (`"hello #{name}"`) | `false` | 1000 | 1000 |

気づき:
- frozen 時はリテラルが**共有**される。1000 回書いても 1 オブジェクト。
- 式展開があると frozen の「同一オブジェクト化」は効かず、新しい String が毎回作られる。よくある「frozen_string_literal を入れたらアロケーションが減る」の恩恵は**式展開していない純粋なリテラル**でしか得られない。
- 単項 `-"..."` は frozen な共有コピーを返す(string interning)。`-\"shared\" == -\"shared\"` で `object_id` まで一致する。動的に生成した文字列を複数回使いたい時に効く。
- 単項 `+"..."` は unfrozen のコピー。frozen 文字列に破壊的操作を乗せたい時の脱出口。

## 03. Encoding と Encoding::Converter

`"日本語 Ruby"` を色々な encoding に入れ直してバイトを観察した。

| 変換 | bytesize | 先頭バイト |
| --- | --- | --- |
| UTF-8 (原本) | 14 | `E6 97 A5 …` |
| Shift_JIS | 11 | `93 FA 96 7B 8C EA …` |
| UTF-16BE | 16 | `65 E5 67 2C …` |
| UTF-16LE | 16 | `E5 65 2C 67 …` |
| UTF-16 (default) | **18** | `FE FF` + UTF-16BE の中身 |

気づき:
- UTF-16 の `encode` は **BOM (`FE FF`) 付きで UTF-16BE** を返す。UTF-16BE / UTF-16LE は BOM なし。endian 固定のつもりなら **BE/LE を明示する**のが安全。
- Shift_JIS ↔ UTF-8 ラウンドトリップは JIS 第一/第二水準漢字で問題なく戻った(`==` で `true`)。ただし絵文字 `😀` は Shift_JIS に無いので `Encoding::UndefinedConversionError`。`undef: :replace, replace: "?"` で救える。
- `force_encoding` は「バイト列はそのまま、ラベルだけ貼り替える」操作。`encode` は「バイト列を書き換える」操作。**無自覚に混同するとデータが壊れる**。
  - 例: ASCII-8BIT な `E6 97 A5 …`(= UTF-8 の「日」)を `force_encoding("UTF-8")` すると正しく `"日"` として読める。
  - 同じデータを `encode("UTF-8", "ASCII-8BIT")` すると `Encoding::UndefinedConversionError`。ASCII-8BIT は「どの文字」を意味するか定義されていないので変換テーブルが無い。
- 変換元/先のどちらが欠けてもエラーにできるのが `Encoding::Converter` の柔軟さ。`universal_newline: true` で CRLF/LF 正規化も同時にできる。

## 04. `==` / `eql?` / `equal?` / `hash`

| ケース | `==` | `eql?` | `equal?` | `hash` 一致 |
| --- | --- | --- | --- | --- |
| 同リテラル (frozen_string_literal: true) | ✅ | ✅ | ✅ | ✅ |
| 同内容で別オブジェクト(`+"abc"`) | ✅ | ✅ | ❌ | ✅ |
| UTF-8 vs US-ASCII (ascii-only) | ✅ | ✅ | ❌ | ✅ |
| UTF-8 vs Shift_JIS (非 ASCII) | ❌ | ❌ | ❌ | ❌ |
| `"foo"` と `:foo` | ❌ | ❌ | ❌ | ❌ |
| NFC `é` vs NFD `e+́` | ❌ | ❌ | ❌ | ❌ |
| frozen vs unfrozen(同内容) | ✅ | ✅ | ❌ | ✅ |

気づき:
- `String#eql?` は「**同じ値**」判定で、frozen やオブジェクト同一性は見ない。
- **ASCII のみの文字列**は encoding が違っても `eql?` で等価扱い&`hash` も一致する。だから UTF-8 の Hash に US-ASCII な同内容キーでアクセスしてもちゃんと拾える。
- 非 ASCII バイトがあると encoding 違いは「別の値」扱い。`Shift_JIS` の `"日本"` で UTF-8 キーの Hash は引けない(見た目は同じでも)。
- **NFC / NFD の `é`** は全滅。Unicode 正規化せずに一致判定すると、ユーザ入力由来の文字列で謎のバグになる温床。`String#unicode_normalize(:nfc)` を意識的にかませる。
- `equal?` は `object_id` の比較。frozen string literal が効いていると、`"abc".equal?("abc")` まで `true` になるのがちょっと面白い。

## 05. 文字列連結のベンチマーク

N = 10000 個の 16 バイト片を 1 本に繋ぐ時間(Ruby 4.0.2, GC 無効, warmup あり)。

| 方式 | 時間 | T_STRING 増分 | オーダ |
| --- | --- | --- | --- |
| `a + b`  | **400 ms** | +10001 | O(N²) |
| `a += b` | **394 ms** | +10001 | O(N²) |
| `a << b` | **0.6 ms** | +1 | O(N) |
| `a.concat(b)` | 0.6 ms | +1 | O(N) |
| `Array#join` | **0.2 ms** | +1 | O(N) |
| `format("%s" * N, ...)` | 0.7 ms | +3 | O(N) |

気づき:
- `+` / `+=` は**毎回**「`acc` の全バイト + `b` の全バイト」をコピーした新しい String を作る。ループで繋ぐと O(N²) になる。**桁で遅い**。
- `<<` / `concat` は末尾に追記するだけなので O(N)。`T_STRING` が +1 で、途中経過の一時オブジェクトが生まれない。
- `Array#join` が最速。先に全長を計算してから 1 回だけバッファを確保している(`join_i` / `rb_str_buf_append` 系の実装)。部品が配列に入っている用途ならこれが素直。
- `format` は `<<` 相当の速度。テンプレートが固定で埋めるだけなら普通に選択肢。
- 「`+` を頑張ってやめる」の効果は、ちっちゃな文字列を大量に繋ぐ時ほど効く。ログ整形・CSV 組み立て・テンプレート展開などで要注意。
