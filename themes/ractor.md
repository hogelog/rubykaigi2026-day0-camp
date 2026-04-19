# Ractor — Ruby の並行処理モデル

## なぜ触るのか

Ractor は Ruby 3.0 で導入された、スレッドよりも安全な並行処理の仕組み。オブジェクト共有を強く制限することで「競合が起きない並行処理」を実現しようとしている。

RubyKaigi では毎年のように Ractor 関連のアップデートや、Ractor を前提にした新機能・新ライブラリの発表がある。Rails では普段使わないが、仕組みを知っておくと本編トークの解像度が一気に上がる。

> **注意**: Ractor の API は Ruby 4.0 で大きく刷新された(`Ractor#take` / `Ractor.yield` / `Ractor.receive_if` の削除、`Ractor::Port` の導入、`Ractor#join` / `Ractor#value` の追加など)。古いブログ記事・書籍のコード例は旧 API 前提のものが多いので、最新の Ruby で動かすときは下記の参考リンクを先に読むこと。

## 触って分かると嬉しいこと

- Ractor 間ではオブジェクトがどう渡るのか(copy / move / shareable の違い)
- 何が shareable で何がそうでないのか
- `Ractor::Port` を使った送受信(`Ractor#send` / `Ractor::Port#receive`)、終了待機の `Ractor#join`、結果取得の `Ractor#value` の使い分け
- 旧 API(`take` / `yield`)から Port ベース設計へ置き換えられた背景
- なぜ「experimental」警告が出続けているのか、現時点の制約

## 取り組みアイデア(難易度順)

### 入門

- `Ractor.new { ... }` を 2〜3 個作って挨拶し合うだけのコードを書く
- 外から変数をキャプチャしようとしたときのエラーを読む
- `Ractor.make_shareable` で Freeze される挙動を観察する

### 中級

- CPU バウンドな処理(例: フラクタル描画・素数列挙・画像変換)を Ractor で並列化して、Thread 版と比較する。**軽めの仕事量だと wall 時間の差は誤差に埋もれて体感しにくい**ので、速度比較よりまず **並列化しているか**を見るのが実験設計として素直。`Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)` で CPU 時間を取り、**cpu / wall 比**を並べると、Thread は本数によらず比 ≈ 1(GVL のため 1 コアしか使えない)、Ractor は比 > 1(複数コアを使う)と並列化度の違いが直接観察できる
- Ractor pool パターンを自分で実装する(ワーカ Ractor を N 個作って仕事を配る)
- Pipeline パターン: 「読み込み → 変換 → 書き込み」を Ractor で段階的に繋ぐ

### 上級

- 既存の gem を Ractor 対応させる(`Ractor.make_shareable` を効かせるために const を frozen にするなど)
- `Ractor::Port` を使った複数 Ractor 間の通信パターンを書く(旧 `take` / `yield` ベースから書き換え)
- Ractor で共有できない値を渡そうとしたときのエラーメッセージから、処理系のどこで判定しているかを追いかける
- **wall 時間でもはっきり Ractor の方が速い**数字を出す。軽い仕事では wall 差は誤差に埋もれるので、仕事を秒オーダー以上に重くする・コア数に応じた分割粒度を揃える・warmup を十分取る、といった実験条件の調整自体がここでの主題

## 予想される詰まりどころ

- ブロック内で外のローカル変数を参照してしまいエラー
- 共有オブジェクトが frozen 化されて、他のコードが壊れる
- Port の receive がブロッキングであることによるデッドロック
- `Ractor::Port#receive` は**作成した Ractor からしか呼べない**(他 Ractor からは `Ractor::Error`)。N 個のワーカが 1 つの共有 job port を食い合う旧来の queue パターンは書けないので、ワーカへの配布は `Ractor#send` + 受け側の `Ractor.receive`(各 Ractor の組み込み mailbox)で行い、結果集約だけを main 所有の `Ractor::Port` で受けるのが定石
- `Ractor.make_shareable(proc)` は Proc の `self` が shareable でないと `Ractor::IsolationError` で弾かれる。トップレベルの lambda の self は main の Object(shareable でない)なので、**純粋関数に見える Proc でも shareable 化は通らないことがある**
- デバッグ時の `puts` 出力がどの Ractor からかわからなくなる問題
- Ractor 内で未捕捉の例外が起きると、main が `#value` で拾う前に `#<Thread:... terminated with exception ...>` が STDERR に噴き出す(main 側で rescue していても出る)
- ネットで見つかるサンプルが旧 API(`take` / `yield`)前提でそのままでは動かない

## 参考リンク

Ractor は設計者である ko1(笹田耕一、STORES)が中心となって開発している領域。STORES Product Blog の解説が最新 API へのキャッチアップに最適。

- **Ractor API の刷新について(ko1, 2025-06-24)**: https://product.st.inc/entry/2025/06/24/110606 — Ruby 3.5 での `take` / `yield` 廃止と `Ractor::Port` / `Ractor#join` / `Ractor#value` 導入の背景と使い方を設計者自身が解説。**まずここから読むと良い**
- Ruby 公式ドキュメント: https://docs.ruby-lang.org/ja/latest/class/Ractor.html
- Ractor 設計ドキュメント(ruby/ruby): https://github.com/ruby/ruby/blob/master/doc/ractor.md
- ko1 の RubyKaigi 過去発表: https://rubykaigi.org/2025/presentations/ko1.html など各年のアーカイブを辿ると Ractor の変遷がそのまま追える

## アウトプットのヒント

- 「Thread だとこう書いていたのが、Ractor だとこうなる」のビフォーアフターを 1 枚で見せる
- ベンチマーク結果を貼る(コア数・Ruby バージョンは必ず併記)
- 詰まったエラーと、それをどう回避したかをそのまま共有する(知見として価値が高い)
