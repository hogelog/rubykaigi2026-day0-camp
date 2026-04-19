# themes/ractor.md への学習者フィードバック

Ruby 4.0.2 で入門・中級・上級を一通り手を動かした結果、ガイドに対して
感じたことのまとめ。「合宿参加者目線で読みやすくするための改善提案」
として残す。

## よかった点

- **冒頭の注意書き「Ruby 4.0 で API が大きく刷新された」が効いた**。この一文のおかげで、ネットの `take` / `yield` サンプルを踏まずに最初から `Port` / `#value` / `#join` を試せた。
- 「触って分かると嬉しいこと」が **copy / move / shareable の違い、Port、旧 API 置き換え** と段階的に並んでいて、そのまま実験タスク化できた。
- 「予想される詰まりどころ」の「**ネットで見つかるサンプルが旧 API 前提**」の明記は強い。先回りで警戒できた。
- STORES Product Blog の ko1 解説へのリンクが **推奨**として明示されているのが助かる。ここから逆引きすれば登壇者文脈(ko1 = Ractor 設計者)も辿れる。

## もう少しあると嬉しかった点

以下は「初見で詰まった」「書いてあれば 15 分救われた」系の具体提案。

### 1. `Ractor::Port#receive` は作成 Ractor しか呼べない、を先に書いてほしい

**一番ハマった**ポイント。「複数ワーカが 1 つの job_port を食い合う」シンプルなプール設計でコードを書いたら、全ワーカが

```
Ractor::Port#receive: only allowed from the creator Ractor of this port (Ractor::Error)
```

で即死した。この制約を踏まえて初めて「ワーカ数分の mailbox に main から send で配る / 結果は main 所有の result_port に many-to-one で集める」という**今風のプール**が書ける。ガイドの「Port を使った送受信」の項に **1 行でも `receive は creator-only`** と書いておくと、旧キューの直感で設計する人の時間を一気に救える。

### 2. Ractor は「デフォルト mailbox」と「明示 Port」の 2 系統がある、を図解してほしい

`Ractor#send` / `Ractor.receive` の組は **各 Ractor の組み込み mailbox** で、`Ractor::Port` とは別物。「**何から何への通信か**」で道具を選ぶと整理しやすい:

- main → 特定 worker: `worker.send` + 受け側 `Ractor.receive`
- N 個の worker → main: main 所有の `Ractor::Port` に worker が `send`、main が `receive`
- 完全な双方向 / select したい: 両側で Port を 1 つずつ作って交換

ガイドにこの 3 つのパターン表があると、ポートを main 側に作るか worker 側に作るかで迷わない。

### 3. 「`make_shareable` したから安全」ではないケースを示す

`Ractor.make_shareable(-> (x) { x * 2 })` は **シンプルな純粋関数でも** 渡せない(`Ractor::IsolationError: Proc's self is not shareable`)。**Proc の self が shareable でないと shareable にできない**。トップレベルの lambda の self は main の Object であり shareable ではない、という仕組みを**具体例 1 個**で添えておくと、`make_shareable` の限界を誤解せずに済む。

shareable な Proc を作りたい時の常道(shareable な定数クラスの特異メソッドや `module_function` 経由)までガイドに書けると上級課題の入り口になる。

### 4. 「send-copy と make_shareable は検査タイミングが違う」を明記する

例として **`Mutex.new` は `make_shareable` できない(`Ractor::Error`)が、`send` で渡すと deep-copy で通る**。各 Ractor が独立した Mutex を持つだけでロック共有の意味は失われるが、**コードは走ってしまう**。「動くけど意味がない」のは事故の温床なので、**どちらで弾かれ、どちらで通り、その結果として何を意味するか**を 1 段落あると良い。

### 5. 「Thread は CPU 並列の道具ではない」を **cpu/wall 比** で見せる

中級の「Thread 版とのスループットを比較する」は **wall 時間だけを比較すると結論が揺れる**。手元で 4 CPU・`2..400_000` の素数カウント・4 分割した時の wall 実測は:

| 方式 | wall | 相対 |
| --- | --- | --- |
| serial | 0.50 sec | 1.00× |
| thread × 4 | 0.58 sec | 0.86×(少し遅い) |
| ractor × 4 | 0.36 sec | 1.40× |

thread×4 と serial の差は 0.08 秒 ≒ 16%。この**差だけを根拠に「GVL で遅くなる」と言うのは乱暴**で、Thread 起動・join のオーバーヘッドでも説明できる範囲。

GVL の効きを**直接**示すなら、`Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)` で CPU 時間を取り、**cpu/wall 比**を見せると一発:

| 方式 | wall | cpu | cpu/wall |
| --- | --- | --- | --- |
| serial | 0.52s | 0.51s | 0.99 |
| thread × 1 | 0.58s | 0.57s | 0.98 |
| thread × 2 | 0.61s | 0.55s | 0.91 |
| thread × 4 | 0.55s | 0.54s | 0.98 |
| ractor × 4 | 0.29s | 0.55s | **1.86** |

**Thread はスレッド数を 1 → 2 → 4 と増やしても cpu/wall が 1 のまま** = 同時に走れるのは 1 本だけ(GVL)。**Ractor は 1.86** = 複数コアを実際に使っている。正しい言い回しは「GVL のため Thread は **並列化できない**(遅くなる、ではない)」。この計測方法自体もガイドに載せると、読者が「Thread が速くならないのは GVL のせいだ」を **自分の目で確かめられる**。

また **Ractor も理論値の N 倍スケールは出にくい**(私の計測では 4 コアで 1.4 倍)。起動コストや初期コンパイルが効くので、**仕事の粒度を十分に重くしないと Ractor 化の恩恵が出ない**、と補足があるとなお良い。

### 6. 未捕捉例外の STDERR ノイズについて触れる

Ractor 内で例外が起きると、親側が `#value` で拾う前に

```
#<Thread:0x... run> terminated with exception (report_on_exception is true):
...
```

が **STDERR に出る**。main 側で try-rescue していても出る。「**うるさいが異常ではない**」「`Thread.report_on_exception = false` 系の発想で黙らせたい場合は...」の注記があると、初見で慌てない。

### 7. `Ractor#value` は一度しか呼べない

旧 `take` はすでに取った値を再度取ろうとすると例外(というか同期原語)だったが、**`value` は「ブロックの戻り値を返すアクセサ」**。**同じ Ractor に対して `value` を 2 回呼ぶと `Ractor::Error`** になる。長時間走るアプリで使い回す時の落とし穴になるので、**「一度だけ」**を強調しておきたい。

## 上級への入り口の設計

- **「処理系のどこで判定しているか」** に踏み込むなら、`ruby/ruby` の `ractor.c` の `rb_ractor_make_shareable` / `obj_traverse_i` / `RB_OBJ_SHAREABLE_P` 近辺が出発点。ガイドに「この関数名を grep すれば入れる」と **具体的な指差し** があると、C ソースに飛び込む勇気が出る。
- エラー分類表(`TypeError: allocator undefined for X` は deep-copy ステップで allocate できないクラス、`Ractor::IsolationError` は shareable 化の静的チェック)を先に置いておくと、読者がエラー文面から即場所を当てられる。
- `ObjectSpace._id2ref` や `Ractor.main` といった **メタ API** の存在も一行だけ触れておくと、デバッグ時に「どの Ractor 目線から見ているか」を混同しなくなる。

## 道具の限界 / 今回の実験で見えなかったこと

- `Ractor.shareable?` の真偽は分かるが、**shareable でない理由がオブジェクト木のどこか**までは標準 API では取れない。深い木で弾かれると原因特定に時間がかかる。`make_shareable(obj, copy: true)` して例外を読むのが現状の現実的なデバッグ。
- pool のスケジューリング効率(ワーカが遊んだ時間 / 待ち時間)は `Benchmark.realtime` だけでは分からない。`Ractor::Port` のキュー長を外から観察する API は公開されていないので、**自前で「受信時刻を記録する結果タプル」を流して測る**のが現状唯一の道。

## メンタルモデルの差分

- 旧来の Ruby 並列処理のメンタルモデルは **「Thread + Mutex + Queue」**。Ractor ではこれが **「Ractor + Port + send/receive(copy / move)」** に置き換わる。対応関係を書くと:

| 旧モデル | Ractor モデル |
| --- | --- |
| スレッドを作る | `Ractor.new` |
| 共有メモリ + Mutex | **共有しない**(copy or move) |
| `Queue` | `Ractor::Port`(creator-only receive) |
| thread.join | `ractor.join` / `ractor.value` |
| 共有可変グローバル | **shareable な frozen オブジェクト**(`make_shareable`) |

**「何を共有しないか」から設計を始める**のが Ractor スタイル、という一文がガイドにあると、読者の思考スタートラインがズレない。

## まとめ

全体として良くできたガイド。**`Ractor::Port#receive` が creator-only という制約**、**Thread vs Ractor ベンチの期待値プレビュー**、**`make_shareable` の限界(特に Proc の self 問題)** の 3 点を足すと、合宿で手を動かす参加者が同じ壁にぶつかる時間を大幅に減らせそう。
