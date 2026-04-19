# TypeProf — 型推論と Ruby

## なぜ触るのか

TypeProf は Ruby のコードを静的解析して RBS を推論するツール。Ruby 3 系では IDE 用のサーバ(`typeprof --lsp`)としても進化している。

RubyKaigi では毎年、RBS / Steep / TypeProf 周辺の発表が複数ある。型を書いていない Rails アプリでも、TypeProf を走らせてみると「Ruby に型を持ち込むと何が見えるのか」が体感できる。

## 触って分かると嬉しいこと

- RBS の基本文法(クラス・メソッド・ジェネリクス・ユニオン)
- TypeProf の推論が得意な所 / 諦める所
- `sig/` ディレクトリ、`.rbs` ファイル、`Gemfile` への gem 追加の作法
- Steep との役割分担
- **`def` の直前に `#: (Integer) -> Integer` と書くだけで、その宣言に反する呼び出しを
  TypeProf 単体で検出できる**(v0.30 以降の Ruby Scripts モード)

## 取り組みアイデア(難易度順)

### 入門

- **まずは 3 行**で挙動を掴む。`echo 'def add(a, b) = a + b; add(1, 2)' > /tmp/t.rb && typeprof /tmp/t.rb` で
  `def add: (Integer, Integer) -> Integer` が出るのを見る。**実引数の型から戻り値を伝播させている** 手触りがつく
- 小さな Ruby スクリプト(50〜200 行程度)に `typeprof` をかけて出力 RBS を読む
- 出力された RBS をわざと壊して、Steep でエラーが出るか確認する
- `rbs prototype runtime` や `rbs prototype rb` との違いを比べる。ざっくりの役割は
  **`rbs prototype rb` は AST から `untyped` の雛形を吐く / `rbs prototype runtime` は
  ロード後にリフレクションで見る / `typeprof` は抽象実行で型を埋める**、の 3 者
- **`def` の直前に `#: シグネチャ`** と書くと TypeProf が宣言として読み、
  `--show-errors` 付きで呼び出しの型違反を検出する。Steep を別途立てる前に試せる:

  ```ruby
  #: (Integer, Integer) -> Integer
  def add(a, b) = a + b

  add(1, "oops") # typeprof --show-errors で型エラーが出る
  ```

- プロジェクト直下で `typeprof --init` を叩くと `typeprof.conf.jsonc` が生成され、
  `rbs_dir: "sig/"` と `analysis_unit_dirs: []` が既定で入る。LSP / エディタ連携でも読まれる

### 中級

- 自分が関わる gem(もしくは社内ライブラリの一部)に RBS を書いて Steep で型チェックを通す
- TypeProf を LSP モードで起動してエディタ(VS Code など)から繋ぐ
- 推論が外れるケースを作って、どう書き直せば推論が効くかを探る(duck typing / メタプロ周り)

### 上級

- 大きめの Rails アプリの一部に TypeProf を適用し、出力をベースに手で RBS を整えて PR サイズまで落とす
- gem_rbs_collection に足りない型定義を追加する PR を書く準備
- TypeProf の内部実装(抽象解釈器)を軽く読んで、どのフェーズで型が決まっているか追う

## 予想される詰まりどころ

- メタプログラミングが絡むと一気に推論が外れる / Any になる
- Rails のような DSL 満載のコードは素の TypeProf だと厳しい(`rbs-rails` などが必要)
- `Gemfile.lock` に含まれる依存 gem の RBS がない問題(gem_rbs_collection を活用)
- エディタ連携の設定でハマる
- **Array リテラルは固定長タプルとして記録される**。`find_even([1, 3, 5])` の引数は
  `Array[Integer]` ではなく `[Integer, Integer, Integer]` と推論される。そのまま RBS に
  コピペすると要素数違いの呼び出しで型が合わないので、`sig/` に置く前に手で `Array[T]` に
  書き直す
- **`Struct.new(:x, :y) do …`** や **`Data.define(:r, :g, :b) do …`** で作るクラスは追えない。
  内側に書いた `def` は `Object` 直下に出てきて `x` / `y` アクセサは見えない。必要なら
  `sig/*.rbs` に手書き RBS を用意する前提で設計する
- **`--show-errors` を付けないと型エラーは沈黙**する。素の `typeprof foo.rb` は RBS を
  吐くだけで型違反を出力しない。型チェッカ的に使いたいときは必ず付ける
- **`Kernel#puts` は `(*String)` として扱われている**。`puts double(3)` のような
  `puts(Integer)` は `--show-errors` で「wrong type of arguments」になる。動作確認の
  プリントデバッグには `p` を使うと摩擦が少ない
- **`#:` アノテーションのキーワード引数の型指定は v0.31 時点では反映されない**。
  `#: (String, ?loud: bool) -> String` と書いても出力は `?loud: false`(デフォルト値の
  値型)になり、呼び出し違反も検出されない。キーワード引数に型を効かせたい場合は
  `sig/*.rbs` 側に書く

## 参考リンク

TypeProf は mame(遠藤侑介、STORES)が作者・メンテナ。あわせて `error_highlight` のようなエラーメッセージ改善も mame の仕事で、RubyKaigi では毎年 TypeProf / 型推論の話を追える。

- TypeProf: https://github.com/ruby/typeprof
- RBS: https://github.com/ruby/rbs
- Steep: https://github.com/soutaro/steep
- gem_rbs_collection: https://github.com/ruby/gem_rbs_collection
- RBS 入門(Ruby 公式ドキュメント): https://github.com/ruby/rbs/blob/master/docs/syntax.md
- **mame の RubyKaigi 2025 発表 "Writing Ruby Scripts with TypeProf"**: https://rubykaigi.org/2025/presentations/mametter.html — TypeProf v0.30 で Ruby 構文をフル対応させた話。現行 TypeProf の立ち位置が分かる(RubyKaigi サイトでのハンドルは `mametter`。各年のアーカイブも辿れる)

## アウトプットのヒント

- 「推論がバッチリ当たった例」と「全然当たらなかった例」をペアで見せると盛り上がる
- 自社コードなど公開できないものは、似た構造のサンプルに落として共有する
- RBS を書いた体験から感じた「Ruby に型を入れると何が嬉しい / 何が面倒」の所感を一言で
