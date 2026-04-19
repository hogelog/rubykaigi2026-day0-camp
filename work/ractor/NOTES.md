# Ractor 学習メモ

RubyKaigi 2026 Day 0 合宿の予習として、Ruby 4.0 で刷新された Ractor を実際に触った記録。

- Ruby: `ruby 4.0.2 (2026-03-17 revision d3da9fec82) +PRISM +GC [x86_64-linux-gnu]`
- 環境: Linux 6.12.43+deb13-amd64, 4 CPU
- API 前提: `Ractor::Port` / `Ractor#join` / `Ractor#value` (Ruby 4.0)。旧 `Ractor#take` / `Ractor.yield` は削除済み。

## 01. 2〜3 個の Ractor で挨拶し合う

`work/ractor/01_hello.rb` は「1 個に `send` で `camper` を送って `value` を受け取る」と「3 個に引数渡しで ID を付けて `value` で集める」の二本立て。

気づき:
- **`Ractor.new do |x|` の引数**はコピー渡し。外側の変数を `|x|` 越しに渡す経路が、最初に覚える「安全な受け渡し」の形。
- **デフォルト受信**は `Ractor.receive`。`Ractor#send` / `<<` で送るとこのキューに入る。`Ractor::Port` はこれと別に明示的な受信口を作りたい時に使う。
- **`Ractor#join` は終了待機、`#value` はブロックの戻り値取得**。`#value` は内部で終了を待つので、戻り値が欲しいなら `join` + 再取得ではなく `value` 一発で済む。
- 起動直後にしれっと `experimental` 警告が STDERR に出る。`Warning[:experimental] = false` で黙らせられる(挙動は experimental のまま)。
- Ractor の `inspect` は `#<Ractor:#2 <file>:<line> running>` 形式。**`#2` は生成順の連番**で、object_id とは別物。

## 02. 外側変数キャプチャと copy / move

`work/ractor/02_capture.rb` で、何が通って何が弾かれるかを横並びに。

| ケース | 結果 |
| --- | --- |
| (a) 外のローカル変数を参照 | `ArgumentError: can not isolate a Proc because it accesses outer variables (name).` |
| (b) 引数経由で渡す | OK |
| (c) トップレベルの frozen 文字列定数 | OK |
| (d) トップレベルの非 shareable 定数(`[]`) | `Ractor::IsolationError` → main では `Ractor::RemoteError` |
| (e) `send(obj)` で渡す(既定) | deep-copy。送り手側は変わらない |
| (f) `send(obj, move: true)` | 送り手側は `Ractor::MovedError`(触ると例外) |

気づき:
- (a) のエラーは **Ractor.new に Proc を渡した時点**で出る(実行前の静的チェック)。中で使っていなくても、**レキシカルに参照している**だけで isolate できずに弾かれる。
- (c) で **frozen_string_literal: true** な定数が通るのは、リテラル文字列が frozen = shareable になるから。`NON_SHAREABLE = []` は同じ「定数」でも shareable でないので (d) で落ちる。
- (d) の `IsolationError` は Ractor の中で起きる → main Ractor から見ると `Ractor::RemoteError`(`#value` で取り出した瞬間に再送出)にラップされる。**例外の層が 2 重になる**のは覚えておかないと混乱する。
- (e) の copy は **deep**。`<<` で要素を足しても送り手側には波及しない。
- (f) の move は「送った瞬間に元を無効化する」ゼロコピーセマンティクス。大きな配列やバッファを渡すなら move。ただし **送り手で再利用しようとすると `Ractor::MovedError`** なので、「もう使わない」保証が取れる時限定。
- (d) のように Ractor 内で未捕捉例外が出ると、STDERR に `#<Thread:… run> terminated with exception (report_on_exception is true):` の形で噴き出す。`Ractor#value` でまとめて受ける構えなら見た目は冗長。
