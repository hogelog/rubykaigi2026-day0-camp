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
