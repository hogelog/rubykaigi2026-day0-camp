# Ractor — Ruby の並行処理モデル

## なぜ触るのか

Ractor は Ruby 3.0 で導入された、スレッドよりも安全な並行処理の仕組み。オブジェクト共有を強く制限することで「競合が起きない並行処理」を実現しようとしている。

RubyKaigi では毎年のように Ractor 関連のアップデートや、Ractor を前提にした新機能・新ライブラリの発表がある。Rails では普段使わないが、仕組みを知っておくと本編トークの解像度が一気に上がる。

## 触って分かると嬉しいこと

- Ractor 間ではオブジェクトがどう渡るのか(copy / move / shareable の違い)
- 何が shareable で何がそうでないのか
- `Ractor.receive` / `Ractor.yield` の send-receive と take の使い分け
- なぜ「experimental」警告が出続けているのか、現時点の制約

## 取り組みアイデア(難易度順)

### 入門

- `Ractor.new { ... }` を 2〜3 個作って挨拶し合うだけのコードを書く
- 外から変数をキャプチャしようとしたときのエラーを読む
- `Ractor.make_shareable` で Freeze される挙動を観察する

### 中級

- CPU バウンドな処理(例: フラクタル描画・素数列挙・画像変換)を Ractor で並列化して、Thread 版とのスループットを比較する
- Ractor pool パターンを自分で実装する(ワーカ Ractor を N 個作って仕事を配る)
- Pipeline パターン: 「読み込み → 変換 → 書き込み」を Ractor で段階的に繋ぐ

### 上級

- 既存の gem を Ractor 対応させる(`Ractor.make_shareable` を効かせるために const を frozen にするなど)
- `Ractor::Port` / `Ractor::Selector` など新しめの API を試す(Ruby バージョン要確認)
- Ractor で共有できない値を渡そうとしたときのエラーメッセージから、処理系のどこで判定しているかを追いかける

## 予想される詰まりどころ

- ブロック内で外のローカル変数を参照してしまいエラー
- 共有オブジェクトが frozen 化されて、他のコードが壊れる
- `Ractor.yield` と `Ractor#take` がブロッキングであることによるデッドロック
- デバッグ時の `puts` 出力がどの Ractor からかわからなくなる問題

## 参考リンク

- Ruby 公式ドキュメント: https://docs.ruby-lang.org/ja/latest/class/Ractor.html
- Ractor 設計ドキュメント(ruby/ruby): https://github.com/ruby/ruby/blob/master/doc/ractor.md
- NEWS for Ruby 3.0 の Ractor セクション: https://www.ruby-lang.org/en/news/2020/12/25/ruby-3-0-0-released/
- 過去 RubyKaigi の Ractor 関連発表(Koichi Sasada 氏など)のアーカイブを漁る

## アウトプットのヒント

- 「Thread だとこう書いていたのが、Ractor だとこうなる」のビフォーアフターを 1 枚で見せる
- ベンチマーク結果を貼る(コア数・Ruby バージョンは必ず併記)
- 詰まったエラーと、それをどう回避したかをそのまま共有する(知見として価値が高い)
