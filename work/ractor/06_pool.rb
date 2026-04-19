# frozen_string_literal: true

# Ractor 中級3: Ractor pool パターン。
#
# Ruby 4.0 で学んだ大事な制約:
#   Ractor::Port は「作成した Ractor からしか receive できない」。
#   ゆえに「複数ワーカが 1 つの job_port を食い合う」パターンは直接は書けない。
#
# 代わりに以下で組む:
#   - main が result_port を 1 つ作る(main だけが receive)
#   - 各 worker には「自分の mailbox」(Ractor.receive) で仕事を配る
#     = main 側は worker.send(job) で特定のワーカに投げる
#   - worker は仕事が終わるたびに result_port.send([id, ...]) で返す
#   - 全ワーカを round-robin で埋める単純なディスパッチャ

require "benchmark"

Warning[:experimental] = false

N_WORKERS = 4
JOBS = (1..20).to_a
STOP = :__stop__

result_port = Ractor::Port.new

workers = N_WORKERS.times.map do |wid|
  Ractor.new(wid, result_port) do |id, results|
    count = 0
    loop do
      task = Ractor.receive
      break if task == :__stop__
      answer = (1..task * 10_000).reduce(:+)
      results.send([id, task, answer])
      count += 1
    end
    count
  end
end

elapsed = Benchmark.realtime do
  # round-robin で各 worker の mailbox に仕事を入れる
  JOBS.each_with_index { |j, i| workers[i % N_WORKERS].send(j) }
  # 終端センチネル
  workers.each { |w| w.send(STOP) }

  JOBS.size.times do
    wid, task, answer = result_port.receive
    puts format("worker=%d task=%-3d answer=%d", wid, task, answer)
  end
end

printf "\npool done in %.3f sec\n", elapsed

per_worker = workers.map(&:value)
puts "per-worker job count: #{per_worker.inspect}"
