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

## 03. shareable? と make_shareable

`work/ractor/03_shareable.rb` で代表的なオブジェクトの `frozen?` / `Ractor.shareable?` を一覧にした。

| 値 | frozen? | shareable? |
| --- | --- | --- |
| `nil` / `true` / `1` / `1.5` / `:sym` | true | **true** |
| `"literal"` (frozen_string_literal: true) | true | true |
| `+"dyn"` | false | false |
| `[1,2,3]` | false | false |
| `[1,2,3].freeze` | true | **true** |
| `[[1]].freeze` (外だけ freeze、内側は未) | true | **false** |
| `{a:1}.freeze` | true | true |
| `Object.new` | false | false |
| `Object.new.freeze` | true | **true** |
| `1..10` (Range) | true | true |
| `->{}` | false | false |
| `Mutex.new` | false | false |

気づき:
- **shareable = 「frozen かつ推移的に全部 shareable」**。`[[1]].freeze` は外だけ freeze で内側が生きているので弾かれる。`.freeze` と shareable は別物。
- `make_shareable(obj)` は **再帰的に全部 freeze** してから shareable にする。その場で元のオブジェクトを破壊的に凍らせるので、**他所で可変のまま使われていると壊れる**。
- 破壊したくない時は `make_shareable(obj, copy: true)`。**frozen な deep copy** を返し、元はそのまま。shareable にしたい既存の設定値などを安全に閉じ込める常道。
- **`Mutex.new` は `make_shareable` できない**(`Ractor::Error: can not make shareable object for ...`)。**同期プリミティブを Ractor 間で共有する従来の発想は崩れる**ので、設計は Port と copy/move ベースに組み替える必要がある。
- closure を持つ lambda(`-> { outer }`) は `Ractor::IsolationError: Proc's self is not shareable`。**「外の環境を拾っている Proc は shareable にならない」**。クラス定数や定数関数参照だけで閉じる Proc(`->(x) { x * 2 }`)は shareable にできる。

## 04. 旧 API (take / yield / receive_if) の非対応を実物で確認

`work/ractor/04_old_api.rb` は Ruby 4.0 における**旧 API 撤去の証拠集め**と**新パターンへの書き換え手本**。

| メソッド | Ruby 4.0.2 での状態 |
| --- | --- |
| `Ractor#take` | **NameError**(instance_method で拾えない) |
| `Ractor.yield` | NameError |
| `Ractor.receive_if` | NameError |
| `Ractor.select` | 生存。引数が `*ports`(旧 `*ractors`)に変わった |
| `Ractor::Port` | 新規。`<<` / `send` / `receive` / `close` / `closed?` / `inspect` |

書き換え対応表:

| 旧パターン | 新パターン |
| --- | --- |
| `r = Ractor.new { compute }; r.take` | `r = Ractor.new { compute }; r.value` |
| producer が `Ractor.yield(x)` / main で `r.take` | producer が `port.send(x)` / consumer が `port.receive` |
| `Ractor.select(r1, r2)` で Ractor を待つ | `Ractor.select(port1, port2)` で Port を待つ |

気づき:
- **旧 API は「非推奨」ではなく「存在しない」**。ネットの blog をそのまま写すと `NoMethodError` / `NameError` で即死するので、サンプルは 2025-06 以降のものに絞る。
- **Port を main から Ractor に渡す**時も、**引数経由で渡すか、shareable な定数経由**でないと閉じ込められない。Port 自身は shareable。
- `port.send(:done)` みたいな **センチネルで終端を伝える**のが自然な書き方になった。旧 `yield` + `take` では「Ractor がブロックを抜けた」が暗黙の終端だったが、Port ベースでは**送信者側が明示する**必要がある。

## 05. Thread vs Ractor(CPU バウンド)

`work/ractor/05_thread_vs_ractor.rb` で `2..400_000` の素数カウントを 4 分割、4 ワーカで並列化。3 回 warmup 後の 1 回計測。4 CPU マシン、`RUBY_DESCRIPTION` は冒頭に記載。

| 方式 | 実行時間(2 回試行) | 相対 |
| --- | --- | --- |
| serial | 0.499 / 0.495 sec | 1.00× |
| thread × 4 | 0.589 / 0.573 sec | **遅い**(0.86×) |
| ractor × 4 | 0.352 / 0.360 sec | **速い**(1.40×) |

気づき:
- **thread × 4 は serial より少し遅く、ractor × 4 は serial より速い**、という方向性は観察できた。ただしこの数字だけでは「thread が遅い」のが **GVL のせいなのか、Thread 起動/join のオーバーヘッドなのか区別できない**(差は 0.08s ≒ 16%、誤差で流せる範囲)。→ 08 で cpu/wall 比を直接測って切り分ける。
- **Ractor は 4 コアでスケール**する方向だが、今回の計測では **1.4× 程度**で線形の 4× には届かない。warmup を 3 回入れてもまだコード初期化(メソッド解決・バイトコードキャッシュなど)の影響が残っている気配。仕事量をもっと増やすと理論値に近づくはず(今回は合計 ~0.5 秒規模なので相対誤差が効く)。
- **Ractor への引数渡し(`Ractor.new(lo, hi) { |l, h| ... }`)**が、`send` より明快。ワーカに渡すデータが 1 回で済むならこれが一番読みやすい。
- `Ractor#value` の配列 `map(&:value)` で集計できるので、Thread の `map(&:value)` と書き味が揃う。**旧 `take` と違い、同じ Ractor に対して `value` を 2 回呼ぶのは禁止**(2 回目は `Ractor::Error`)。

### 05 への追試: GVL を直接計測する (08)

05 の数字 (serial 0.50s / thread×4 0.58s) だけでは「thread×4 が serial より遅いのは GVL か、Thread 起動・join のオーバーヘッドか」区別できなかった。`work/ractor/08_gvl_evidence.rb` では `Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)` でプロセス全体の CPU 時間を測り、**cpu/wall 比で並列化度を直接観察**する。

| 方式 | wall | cpu | cpu/wall | 解釈 |
| --- | --- | --- | --- | --- |
| serial | 0.516s | 0.509s | 0.99 | 1 コア分 |
| thread × 1 | 0.579s | 0.569s | 0.98 | 1 コア分 |
| thread × 2 | 0.609s | 0.554s | 0.91 | **1 コア分のまま**(並列化していない) |
| thread × 4 | 0.545s | 0.535s | 0.98 | 同上 |
| ractor × 4 | 0.294s | 0.546s | **1.86** | 複数コアを使っている |

気づき:
- **Thread は何本立てても cpu/wall ≈ 1.0**。GVL のため同時に走れるのは 1 本だけ、というのがこの比で一発で見える。
- **Ractor は cpu/wall ≈ 1.86**。4 ワーカ用意したが仕事量が小さく (合計 wall 0.3s)、Ractor 起動コストで線形 4 倍には届かない。仕事を重くすれば 4 に近づく方向。
- 「GVL のせいで Thread が **遅くなる**」という素朴な言い方は**不正確**。正確には「**GVL のため Thread は並列化できない**ので、スレッドを増やしても serial と大差ない。差が出るのは起動・切り替えのオーバーヘッド分」。05 の thread×4 が serial より遅く見えたのは、仕事量に対する相対オーバーヘッドが効いただけ。
- wall 単独ではこの区別ができない。`CLOCK_PROCESS_CPUTIME_ID` の cpu 時間 / wall 時間 **比** を見るのが GVL の効きを示す直球の計測。


## 06. Ractor pool パターンと Port の所有制約

`work/ractor/06_pool.rb` は 4 ワーカに 20 ジョブを round-robin で配るシンプルなプール。

**最初にハマった落とし穴**: Port を main で 1 つ作ってワーカに渡し、「workers 全員が同じ job_port を食い合う」 旧来の queue パターンを書いたら、

```
Ractor::Port#receive: only allowed from the creator Ractor of this port (Ractor::Error)
```

で全ワーカが即死。**`Ractor::Port#receive` は作成 Ractor にしか許されない**(= Port は所有物)。send は誰からでも可。つまり Port は「単独 consumer、複数 producer」向け。

これを踏まえた実際のプールの組み方:

| 向き | 道具 |
| --- | --- |
| main → 特定 worker(仕事を配る) | `worker.send(job)` + ワーカ側 `Ractor.receive`(各 Ractor の組み込み mailbox) |
| worker → main(結果を返す) | `result_port.send(result)`(main 所有の `Ractor::Port`) |
| 全部終わったことの合図 | main から各 worker に `STOP` シンボルを `send` |

結果:

```
per-worker job count: [5, 5, 5, 5]
pool done in 0.075 sec
```

気づき:
- Ractor には **デフォルトの mailbox(`Ractor.receive` / `Ractor#send`)** と **明示的な `Ractor::Port`** の 2 系統がある。どちらも「一人の consumer, 複数の producer」なのは共通。
- **Many-to-one(例: 複数ワーカから main へ結果集約)** は `Ractor::Port` 一つで綺麗に書ける。
- **One-to-many(例: job キューを全ワーカが食い合う)** は **直接は書けない**。ディスパッチャを main 側に置いて `worker.send` で投げ分けるか、間に「ディスパッチャ Ractor」を立てて select する設計になる。
- 「**ワーカプール=共有キュー**」の直感は旧 `Ractor.yield`/`take` ベースの blog の影響で残りがちだが、Ruby 4.0 の API では **ワーカ数分の mailbox に送り分ける**のが素直。

## 07. 共有できない値を渡したときのエラー分類

`work/ractor/07_unshareable.rb` で send できる / できないを横並びに。

| ケース | 結果 |
| --- | --- |
| (a) `send(Mutex.new)` | **OK**(deep-copy が通る) |
| (b) `send(STDOUT)` | **OK** |
| (c) closure を持つ Proc | `TypeError: allocator undefined for Proc` |
| (d) `make_shareable(-> (x) { x*2 })` | `Ractor::IsolationError: Proc's self is not shareable` |
| (e) `Box` 越しに Array ivar | OK(Array が deep-copy される) |
| (f) `Box` 越しに Mutex ivar | OK(ivar も deep-copy される) |
| (g) `method(:puts).to_proc` | `TypeError: allocator undefined for Proc` |
| (h) `send(Thread.new { ... })` | `TypeError: allocator undefined for Thread` |

気づき:
- **「Mutex は shareable にできないが send-copy はできる」** — 各 Ractor が独立した Mutex を持つだけなので安全、ただしロック共有の意味は消える。`make_shareable` で弾く / send で通す、という**検査タイミングの違い**を示している。
- エラーが 2 系統に分かれる:
  - **`TypeError: allocator undefined for X`**: そもそも allocate できないクラス(Proc, Thread, UnboundMethod など)。main 側の **deep-copy ステップ**で即死。
  - **`Ractor::IsolationError`**: shareable 化の静的チェックで弾かれるケース。
- **`make_shareable(proc)` は万能ではない**。**Proc の `self` が shareable でない**と通らない。トップレベル lambda の self は main の Object。shareable な定数クラスの特異メソッドや `Module#module_function` 経由で作った Proc だけが候補になる。
- **STDOUT が send できる**のは IO としての特別扱い(writable な共有リソースは実運用では排他制御が要る)。ここは *できる* と *すべき* が一致しない典型例。

道具の限界 / 次に見るべきもの:
- どこで弾かれているかの実装は C 側。`rb_ractor_make_shareable`, `ractor_move`, `rb_ractor_copy` あたりを `ruby/ruby` の `ractor.c` で追うのが次の一歩。
- send / make_shareable の検査は **grep の出発点として `ractor.c` の `obj_traverse_i` / `RB_OBJ_SHAREABLE_P`** が分かりやすい。
