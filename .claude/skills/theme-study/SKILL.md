---
name: theme-study
description: RubyKaigi 2026 Day 0 合宿のテーマ(themes/*.md)を一つ取り上げ、実際に手を動かしてコードで確かめ、work/ に観察ログを積み上げて最後にガイドへのフィードバックまで出すループ。ユーザが「string テーマやってみる」「ractor で手を動かしたい」「typeprof 触ってみる」など themes 配下のトピックで学習したいと言ったときに起動する。
---

# テーマ学習ループ

RubyKaigi 2026 Day 0 合宿の各テーマ(`themes/<topic>.md`)を、**読む → 動かす → 残す → 資料にフィードバック**の 4 段階でひと回しする手順。

## 起動条件

- ユーザが `themes/` 配下のトピック名(ractor / typeprof / irb-reline / string / build-ruby など)を挙げて学習を始めたいと言ったとき
- 「手を動かして学びたい」「予習したい」の文脈

## 手順

### 0. 前提確認と過去ログの参照

- `ruby -v` で Ruby のバージョンを確認し、**`RUBY_DESCRIPTION`** を NOTES.md の先頭に必ず書く(挙動がバージョン依存する領域が多い)。
- 足りない gem があれば `gem install` を提案する。ベンチは stdlib `Benchmark.realtime` だけで十分なので、元のガイドに無い gem は原則持ち出さない。
- **既存の `work/*/` を先に眺める**。過去テーマの `NOTES.md` / `FEEDBACK.md` を読むと、このリポジトリでどういう粒度・切り口で記録が積まれているか(表 + 気づき + 出典ガイドへの差分)が掴める。`git log --oneline main..HEAD` と `git log --oneline origin/main -10` で「過去の自分の実験」と「すでにガイド側に還流済みの改善」を確認する。

### 1. 作業ブランチと作業ディレクトリを用意する

```sh
git checkout work/camp-study      # 存在しなければ `git checkout -b work/camp-study` から
git pull --ff-only origin main    # リベース不要・共有ブランチではないので直接は push しない
mkdir -p work/<theme>
```

- **ブランチは単一の `work/camp-study`**。テーマが増えるたびにブランチを切らず、同じブランチに `work/<theme>/` を追加していく。履歴で学習の横断が追える。
- `work/camp-study` は main にはマージしない前提の実験ブランチ。リモートに push するかはお好み(他人と共有する必要がなければ手元だけでも可)。
- 作業ファイルは `work/<theme>/` 配下に。`NOTES.md`・`FEEDBACK.md`・番号付き `NN_xxx.rb` の構成が扱いやすい。

### 2. テーマガイドを読み、TaskCreate で小分けにする

- `themes/<theme>.md` を通読する。
- 「触って分かると嬉しいこと」と「取り組みアイデア(入門/中級/上級)」を元に、**1 タスク = 1 Ruby スクリプトで検証できる粒度**に落とす。
- 入門 → 中級 → 上級 の順で進める。上級は時間と興味次第で止めても良い。

### 3. 実験 → 観察 → NOTES.md を繰り返す

各タスクについて:

1. `work/<theme>/NN_xxx.rb` を書く(数十行の最小スクリプト)。
2. `ruby work/<theme>/NN_xxx.rb` で走らせる。
3. 出力を `NOTES.md` に**表 + 気づきの箇条書き**で残す。出力そのものより「驚いた点・他の挙動との比較・落とし穴」を言語化する。
4. **1 実験 = 1 コミット**。コミットメッセージは「何を観察したか / 何が分かったか」を 2〜3 行で。
   - 例: `work/string: 文字列連結のベンチマーク // + / += は O(N^2), << は O(N)`

#### 実験コードのお約束

- 自明でない限り `# frozen_string_literal: true` を付ける(アロケーションノイズを減らす)。
- ベンチマークは **warmup を明示**し、`GC.disable` の有無を NOTES に併記する。
- 観察値は表形式で残す。定量値(time, bytesize, count など)+ 備考の列で並べる。
- 予期せぬ例外が出たら潰さずに、メッセージごと NOTES に保存。それ自体が学び。

### 4. ガイドへのフィードバックを `work/<theme>/FEEDBACK.md` にまとめる

実験を全部終えたあと、**ガイド読者目線で**:

- **よかった点**: 事前に読んでおいて助かった記述、段階設計、参考リンクなど。
- **もう少しあると嬉しかった点**: 初見で詰まった・書いてあれば時間を節約できた具体ポイント。各項目は「発生した状況 → こういう 1 行があれば救われる」の形で。
- **上級への入り口の設計**: 上級課題に進む際の最初の一歩となるスニペットや「どの定数/関数から読めばいい」の指差し。
- **ガイドのメンタルモデルが古い箇所**: 実験してみて「ガイドの前提が Ruby の古いバージョンの姿」だったと分かった場合、観察結果を根拠にメンタルモデルの差分を書く(例: string テーマの「embedded / heap 2 値」は Ruby 4.0 の VWA では複数段階になる)。Kaigi 本編の登壇者の文脈と結びつけて、「この観察は誰のトークの前座になるか」まで書けるとなお良い。
- **道具の限界の明示**: 使ったツール(`memsize_of`, `count_objects`, ベンチなど)で**見えないこと**も書き添える。次の道具(`ObjectSpace.dump`, `gdb`, C ソース)への導線になる。

FEEDBACK.md は合宿の運営にそのまま渡せる粒度にする(後で PR 化する前提で)。

### 5. コミットとブランチの扱い

- `git log --oneline main..HEAD` で 1 実験 1 コミットになっているか点検する。
- feedback のコミットは最後に単独で。
- `work/camp-study` ブランチはあくまで実験のストレージ。main へのマージはしない。

### 6. ガイド改善 PR は別ブランチから切る

FEEDBACK.md のうち「元ガイドに足すと読者が救われる」項目は、`themes/<theme>.md` への加筆として main に還流させる。

```sh
git checkout -b docs/<theme>-learning-feedback origin/main  # main から分岐、work/camp-study からは切らない
# themes/<theme>.md を surgical に編集(既存構造は温存、加筆中心)
git add themes/<theme>.md
git commit -m "themes/<theme>.md: 合宿参加者視点のフィードバックを反映"
git push -u origin docs/<theme>-learning-feedback
gh pr create --base main --title "..." --body "..."
```

- PR には **観察ログそのもの**(`work/<theme>/NN_*.rb` や `NOTES.md`)は含めない。`work/camp-study` に残し、PR の本文で「元ネタはこのブランチ」と参照するに留める。
- 各フィードバック項目について、加筆した本文に「**なぜ追加するか** = どういう詰まり方を救うか」を一行で言えるか自問する。理由がぼやけたら PR に含めない(FEEDBACK には残しておく)。
- 元ガイドに無かった前提(特定の gem など)を増やさない。stdlib や標準機能でまかなえる書き方を優先する。

## アンチパターン

- 大きなスクリプトを一本書いて「だいたい動いた」で止める。実験単位を小さく切り、**1 観察 = 1 ファイル = 1 コミット**が鉄則。
- 出力を貼るだけで気づきを書かない NOTES。あとで読み返す価値が落ちる。
- ガイドを完璧な状態として読む。**学習者が詰まった箇所はガイドの改善点**として記録する姿勢で臨む。
- Ruby のバージョンを書き忘れる。挙動差で再現できない学びは価値半減。
- ガイドに書いてあることを**鵜呑みにして現物で確認しない**。手元の Ruby で期待値が違ったら、ガイドが古い可能性を疑って FEEDBACK に残す。

## 成果物チェックリスト

- [ ] `work/<theme>/NOTES.md` に Ruby バージョンと各実験の表 + 気づきが並んでいる
- [ ] `work/<theme>/NN_*.rb` がそのまま `ruby` で実行可能
- [ ] `work/<theme>/FEEDBACK.md` に**具体的な**改善提案がある
- [ ] 実験コミットは `work/camp-study` ブランチに、ガイド改善 PR は `docs/<theme>-learning-feedback` ブランチに分かれている
- [ ] コミット履歴(`git log --oneline main..HEAD`)を辿れば学習の道のりが追える
