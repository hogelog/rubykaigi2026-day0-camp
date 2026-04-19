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
