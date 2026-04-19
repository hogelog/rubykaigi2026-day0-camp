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

## 02. rbs prototype rb / runtime と typeprof の比較

同じ `01_basic.rb` に対して 3 つの RBS 生成ツールを並べた。

| ツール | 入力の読み方 | `Counter#add` の型 | `double(x)` の型 | `attr_reader count` の型 | コメント |
| --- | --- | --- | --- | --- | --- |
| `rbs prototype rb` | **AST を静的に** 読む(実行しない) | `(untyped n) -> self` | `(untyped x) -> untyped` | `untyped` | 末尾式の `self` を見て戻り値 `self` を拾うぐらいの軽さ |
| `rbs prototype runtime` | **ロードしてからリフレクションで** 見る | `(untyped n) -> untyped` | (トップレベル関数は見ない) | `untyped` | `Method#parameters` 経由なので型情報ゼロ、ただしクラス階層と public/private は正確 |
| `typeprof` | **抽象実行** で型を伝播させる | `(Integer) -> Counter` | `(Integer) -> Integer` | `-> Integer` | 引数/戻り値/インスタンス変数の型が実際に出る |

気づき:

- **「型を埋める」のは typeprof だけ**。rbs prototype 系は `untyped` の雛形を吐くのが仕事。
  人間が埋める前提で、「クラス名・メソッド名・引数名・public/private」を先取りしてくれる
  下書きジェネレータ。
- `rbs prototype rb` は **実行しない**ので、副作用のあるスクリプトでも安全。反面、
  require で拾うような動的クラスは見えない。
- `rbs prototype runtime` は **ロードが必要**。今回は `--require-relative ./work/typeprof/01_basic`
  を付けたが、この副作用でスクリプトの `puts` 出力がそのまま漏れる。本番相当の
  依存を全部 require することになるので、Rails アプリなどで走らせると重い。
  逆に **C 拡張やメタプロで動的に生えるメソッドも見える**のが利点。
- `rbs prototype rb` の `Counter#add: (untyped n) -> self` は面白い: **メソッドの最後の式が
  `self`** という**構文的な事実**だけで戻り値 `self` を付けられる。typeprof は実行を
  伝播させて `Counter` を返すと書くので、**"self 型"を保てるのはむしろ rbs prototype rb**
  という逆転がある。
- トップレベルの関数(`double` など)は **`rbs prototype runtime` からは見えない**
  (`Object` の private method だが CLI に渡したクラス名しか出さないため)。
  一方で `rbs prototype rb` は AST から見える。**ツールの守備範囲の違い**。
- 使い分けの肌感:
  - **新規コードに RBS 雛形を付けたい** → `rbs prototype rb` で枠組みを作り、型を手で埋める
  - **既存 gem の型を書き始めたい**(DSL で動的にメソッドが生えるなど) → `rbs prototype runtime`
  - **本気で型を推論させて型チェックしたい** → `typeprof`(ただし呼び出し側のコードが必要)

## 03. 推論が外れるケース(メタプロ / Duck typing)

`work/typeprof/03_metaprogramming.rb` で、よく使う動的機能に typeprof 0.31 をかけた。

| ケース | typeprof の挙動 | 備考 |
| --- | --- | --- |
| (a) `define_method(:name) { ... }` を `each` で撒く | **クラスが空のまま**。呼び出し側が `undefined method: DynamicMethods#ping` | クラス定義の中でのループは抽象実行されない |
| (b) `method_missing` + `respond_to_missing?` | `method_missing: (untyped, *untyped) -> String` は出るが、**`.whatever` 呼び出しは `undefined method`** | method_missing はただのメソッドとしてしか見ない |
| (c) `send(method_name, arg)` | `def call: (:greet, String) -> untyped`、戻り値は **untyped に落ちる** | 引数は **シンボルリテラル `:greet`** として記録される(`Symbol` ではない) |
| (d) `obj.respond_to?(:size)` で分岐 | `(Integer \| String \| [Integer, Integer, Integer]) -> Integer` | **ユニオン推論は効く**。`-1` と `obj.size` が両方 Integer なので合成は `Integer` |
| (e) `Struct.new(:x, :y) do …` | クラスが生えず **`Point: untyped`**。内側の `def distance_from_origin` は **`Object` 直下**に出力 + `undefined method: Object#x` エラー | Struct 生成を追わないので `x` / `y` アクセサが生えない |
| (f) `Data.define(:r, :g, :b) do …` | (e) と同じ。`RGB: untyped`、`luminance` は `Object` 直下。`0.299 * r` で `failed to resolve overloads` | Data.define も追わない |

気づき:

- **TypeProf が諦めるのは「実行時に形が決まる」構造**で、(a) define_method、(e) Struct、
  (f) Data がその代表。**クラスのかたち自体**がメタプロで作られるとお手上げ。
  逆に言えば、**RBS を人間が書いて `sig/` に置く**ことでここだけ補うのが実運用。
- (c) `send` の **戻り値は untyped** になる。`method_name` が `:greet` というシンボル
  リテラルとして残っているのに、そこから呼ぶ先の `greet` まで辿ってくれない。
  これは「リテラル値依存で分岐できる高度な解析」の範囲で、現 TypeProf は踏み込まない。
- (d) **duck typing は `respond_to?` 込みで意外に効く**。特に「その分岐内で確実にそのメソッド
  が呼べる」だけ見て型を出す。ただし `read_size` の引数型が **`[Integer, Integer, Integer]`
  のタプル**(実引数の `[1,2,3]` 由来)で残っていて、他の長さの Array を渡すと未対応になる
  のは 01 と同じ癖。
- (b) `method_missing` の戻り値 `String` は **`method_missing` 本体** の戻り値を
  そのまま RBS にしてくれるので、**`respond_to_missing?` が true を返す前提で
  `#whatever` を `method_missing` 経由で飛ばしてみる**みたいな合成はしない。これをやるには
  人間が `sig/` 側に `def whatever: ...` を書き足す必要がある。
- `--show-errors` が無いと上記のエラー群は**沈黙する**。雛形生成としてだけ使うなら
  エラー無しで、RBS の質を確かめたい時は付ける、という二段構えが実用的。

## 04. ユニオン / 戻り値分岐 / 引数分岐 の境界

`work/typeprof/04_union_boundary.rb` — TypeProf が**ちゃんと推論してくれる範囲**の地図。

| ケース | 入力 | 出力 RBS | コメント |
| --- | --- | --- | --- |
| (a) `case` で戻り値 | `pick(:int/:str/:other)` | `(:int \| :other \| :str) -> (Integer \| String)?` | 分岐ごとの戻り値が綺麗に合成 |
| (b) 多型で同じ関数を呼ぶ | `identity(1/"two"/:three/[1,2])` | `(:three \| Integer \| String \| [Integer, Integer]) -> (…同じ…)` | **引数 = 戻り値** をそのまま伝播。ジェネリクスにはならない |
| (c) Array リテラルの要素ユニオン | `[1, "two", :three, nil]` | `-> [Integer, String, :three, nil]` | **タプル**化されて `Array[union]` にはならない |
| (d) Hash リテラル | `{ a: 1, b: "two" }` | `-> Hash[:a \| :b, Integer \| String]` | キーはシンボルリテラルユニオン, 値もユニオン(Hash は健全) |
| (e) `&.` による nil 伝播 | `s&.upcase` | `(String?) -> String?` | 安全ナビゲータは正しく nil 合流 |
| (f) 複数 `return` | `classify(1/-1/0)` | `(Integer) -> (:neg \| :pos \| :zero)` | early return もまとめて合成 |
| (g) リテラル + 算術 | `x = 10; x + 1` | `-> Integer` | **算術が入るとリテラル型 → 一般型**に汎化 |
| (h) ブロックを受ける | `yielder(3){...}` と `yielder("x"){...}` | `(Int\|Str) { ((Int\|Str)) -> (Int\|Str) } -> (Int\|Str)` | **呼び出しごとの関係は追わない**(Int→Int と Str→Str を別オーバーロードにしない) |

気づき:

- **Hash はタプルにならない**が、**Array はタプル化する**。この非対称は初見だと意外。
  理由は多分、Array リテラルの長さが固定(静的に見える)だから。逆に言えば
  「典型的な要素型を書きたい」なら **`Array[T]` は手で書く**必要がある。
- **(b) の ID 関数でジェネリクスが出ない**のが現行 TypeProf 0.31 の限界。
  これは意図的で、TypeProf は **(引数型, 戻り値型) のペアをメソッドごとに 1 つ**持つ方針。
  呼び出しごとの依存を追うには「型変数」が必要で、v0.30+ の再設計でも入ってはいない。
- **(g) のリテラル → 一般型への汎化**は `+ 1` のような**算術を挟むと起きる**。
  何もしない `x = 10; x` だと推論は `10` のまま(シンボルリテラル型のように見える)
  可能性があるので、次実験で切り分ける価値がある。
- **(h) のブロックの型**は、呼び出し箇所 2 つを合成したユニオン 1 本に潰れる。
  **「Integer を渡したら Integer が返る」という呼び出しごとの相関は保てない**。
  型安全性としては `Integer` を渡しても `(Integer | String)` が返る RBS になる。
  実用では十分だが、generic な `map` 的 API を書きたい人には厳しい。
- (a) `pick` の戻り値記法 `(Integer | String)?` は **RBS の糖衣**で、意味は
  `(Integer | String) | nil`。複数の値 + nil を畳む時に頻出するので目に慣らしておく。
