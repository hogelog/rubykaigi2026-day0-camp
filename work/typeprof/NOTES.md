# TypeProf 学習メモ

RubyKaigi 2026 Day 0 合宿の予習として、TypeProf を実際に走らせて出力を読み、
「何が推論できて何が諦められるか」を手で確認した記録。

- Ruby: `ruby 4.0.2 (2026-03-17 revision d3da9fec82) +PRISM +GC [x86_64-linux-gnu]`
- gem: `typeprof 0.31.1` / `rbs 3.10.0`
- 環境: Linux 6.12.43+deb13-amd64
- `typeprof` コマンドが PATH に乗っていないので、以降の実行は
  `ruby /usr/lib/ruby/gems/4.0.0/gems/typeprof-0.31.1/bin/typeprof` をエイリアスにしている想定。

## 01. 小さなサンプルに typeprof をかけて RBS を読む

`work/typeprof/01_basic.rb` — クラス・キーワード引数・Array/Hash・ブロック・継承を
混ぜた 60 行ちょい。`typeprof work/typeprof/01_basic.rb` の出力:

```
class Object
  def double: (Integer) -> Integer
  def greet: (String, ?loud: bool) -> String
  def find_even: ([Integer, Integer, Integer]) -> Integer?
  def histogram: ([String, String, String, String, String, String]) -> Hash[String, Integer]
end
class Counter
  def count: -> Integer
  def initialize: (?Integer) -> void
  def add: (Integer) -> Counter
  def reset: -> nil
end
class ShoutCounter < Counter
  def add: (Integer) -> Counter
end
```

気づき:

- **Array 引数がタプル型で出る**。`find_even([1,3,5])` と `find_even([1,2,3])` の両方を
  渡したら、共通の `[Integer, Integer, Integer]`(**要素数固定のタプル**)が推論された。
  `Array[Integer]` にはならない。**呼び出した実引数の形を覚えて返す**挙動で、汎化は弱い。
  `histogram` も同様で `[String, String, String, String, String, String]`(6要素固定)。
  このまま RBS として使うと「5 要素や 7 要素の配列を渡すと型が合わない」未来が待っている。
- トップレベル定義は全部 `class Object` 直下に生える。スクリプト向け TypeProf の流儀。
- `?loud: bool` のようにキーワードの省略可能性(`?`)と値の型(`bool`)は取れている。
- `?Integer` (`initialize`) のように **デフォルト引数 → 省略可能** も取れる。
- `attr_reader :count` は `def count: -> Integer` として RBS 化される。`@count` の型は
  `Counter#initialize` と `#add` / `#reset` の代入を合成して **Integer** に落ちている。
- `Counter#add` は `self` を返すのに、RBS 出力は **`-> Counter`**(self 型ではない)。
  `ShoutCounter#add` も `super(...)` 経由で **`-> Counter`** になる。つまり **`self` の
  伝播ではなくその時点のクラスで固定**される。`sc.add(-5).add(-1)` のように
  `ShoutCounter` であるはずのインスタンスが RBS 上は `Counter` として伝わる点に注意。
- `--show-errors` を付けると **line 60 (`puts double(3)`) / 69 (`puts c.count`) /
  73 (`puts sc.count`) に "wrong type of arguments"** が出る。最小再現
  (`work/typeprof/01_basic_str.rb`) で切り分けた結果、**原因は `puts(Integer)`**。
  `puts` に String 以外を渡すと typeprof 0.31 の組み込み RBS では型エラー扱い。
  `p(Integer)` は通る。RBS 全体では `Kernel#puts : (*String) -> nil` で定義されていて、
  一般的な「`puts` は何でも受ける」感覚とギャップがある。初見だと「サンプルに
  `puts 1` を書いた瞬間エラー」で戸惑うので覚えておく。
- `--show-errors` を付けないと TypeProf はエラーも「RBS を埋めるヒント」として
  使って推論するだけで、標準出力には出さない。**エラーを見たい時だけ明示する
  オプション**という思想。
