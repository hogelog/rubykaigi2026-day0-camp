# Ruby 予習タイム合宿 @ RubyKaigi 2026 Day 0

**普段触れない Ruby の重要部品に手を動かして向き合おう**

RubyKaigi 2026 を最大限楽しむための Day 0 合宿予習コンテンツ。

## コンセプト

RubyKaigi では言語処理系そのものや、Ruby を支える基盤技術に関する話が多く発表される。一方、例えば Rails アプリケーションを書いているだけではそうした Ruby の "内側" に触れる機会は意外と少ない。

この手を動かすタイムは、RubyKaigi 本編を数倍楽しむための予習として、参加者それぞれが興味のある Ruby の重要部品を触ってみようという時間です。Kaigi 本編で飛び交う話題の「基礎体力」をつけることが目的です。

## ねらい

- RubyKaigi で扱われるトピックに対して、自分の手で動かした経験を持ってから臨む
- 普段 Rails 開発では深く踏み込まない領域(並行処理・型・REPL・文字列の内部表現など)に触れる

## 取り扱うテーマ

メインの興味対象として以下を想定。どれを選ぶか、どの深さで掘るかは各自自由です。もちろん、RubyKaigi のための学びだと信じられるものだったら他の何でも OK。

| テーマ | 概要 | ガイド |
| --- | --- | --- |
| Ractor | 並行処理モデルの理解、Ractor ベースのアプリケーション実装 | [themes/ractor.md](themes/ractor.md) |
| TypeProf | 型推論ツールを自社システムに適用、出力を読み解く | [themes/typeprof.md](themes/typeprof.md) |
| IRB / Reline | IRB の拡張コマンド実装、Reline を使った CLI アプリ開発 | [themes/irb-reline.md](themes/irb-reline.md) |
| String | Ruby の文字列がどういうデータ構造なのかを処理系レベルで理解 | [themes/string.md](themes/string.md) |

周辺テーマとして、[ruby/ruby master をビルドして自分のデフォルト ruby にしてみる](themes/build-ruby.md) なども歓迎。

## 進め方(タイムテーブル例)

| 時間 | 内容 |
| --- | --- |
| 0:00 - 0:15 | **オープニング** — コンセプト共有、各自の取り組みテーマ宣言 |
| 0:15 - 3:30 | **もくもく深掘りタイム** — 各自のテーマでひたすら手を動かす |
| 3:30 - 4:30 | **ぷち成果発表会** — 一人数分ずつ、何を調べて何を作ったか・何が分かったかをシェア |

もくもく中は雑談・質問歓迎。詰まったら周りに声をかける、途中で別テーマに乗り換えるのも自由。

## 成果物

- 各自の手元で動くコード・実験結果
- 発表資料(スライドでも口頭でも REPL デモでも可)

## 当日の持ち物 / 事前準備

- Ruby 4.0 推奨。可能なら ruby/ruby master をビルドしておくとなおよし
- Ruby のバージョン管理は STORES 社内では mise が基本(他のツールでももちろん OK)
- **ruby/ruby は事前に clone だけでも済ませておくのがおすすめ** — RubyKaigi 本編で触れられる PR やコードを手元で `git grep` / `gh pr checkout` で追うとき、clone 済みだと段違いに速い。ビルドまでやるかは任意
  ```sh
  git clone https://github.com/ruby/ruby.git
  ```
- ruby/ruby を手元でビルドしたい人は [themes/build-ruby.md](themes/build-ruby.md) を参照して前日までにビルド環境を整えておくとスムーズ
- エディタ、好みのターミナル、元気と好奇心

## 参考: RubyKaigi 本編との接続

本編のタイムテーブルが出たら、自分の選んだテーマに関連するセッションを事前にピックアップしておくと、合宿の成果をそのまま本編で活かせます。

- RubyKaigi 2026 公式: https://rubykaigi.org/2026/
- 過去の RubyKaigi アーカイブ: https://rubykaigi.org/
