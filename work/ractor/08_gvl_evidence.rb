# frozen_string_literal: true

# Ractor 追試: 「Thread は GVL で CPU 並列化しない」を数字で立証する。
#
# 05 では thread×4 が serial より少し遅いだけで、GVL の直接証拠にはならなかった
# (Thread 起動・join のオーバーヘッドでも説明がつく誤差範囲だった)。
#
# ここでは Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) で
# プロセス全体の CPU 時間を測る。
#   - 並列化できていれば: wall < cpu(複数コア合算で CPU 時間が増える)
#   - 並列化できていなければ: wall ≈ cpu(1 コア分)

Warning[:experimental] = false

def count_primes(from, to)
  count = 0
  (from..to).each do |n|
    next if n < 2
    is_prime = true
    d = 2
    while d * d <= n
      if n % d == 0
        is_prime = false
        break
      end
      d += 1
    end
    count += 1 if is_prime
  end
  count
end

TOTAL = 2..400_000
WORKERS = 4
CHUNK = ((TOTAL.max - TOTAL.min) / WORKERS.to_f).ceil
CHUNKS = WORKERS.times.map do |i|
  lo = TOTAL.min + i * CHUNK
  hi = [lo + CHUNK - 1, TOTAL.max].min
  [lo, hi]
end

def measure(label)
  3.times { yield } # warmup
  GC.start
  wall0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  cpu0  = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
  yield
  wall1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  cpu1  = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
  wall = wall1 - wall0
  cpu = cpu1 - cpu0
  printf "%-14s wall=%.3fs cpu=%.3fs cpu/wall=%.2f\n", label, wall, cpu, cpu / wall
end

puts "Ruby: #{RUBY_DESCRIPTION}"
puts "workers=#{WORKERS} chunks=#{CHUNKS.inspect}"
puts

measure("serial") do
  CHUNKS.each { |lo, hi| count_primes(lo, hi) }
end

measure("thread x1") do
  Thread.new { CHUNKS.each { |lo, hi| count_primes(lo, hi) } }.join
end

measure("thread x2") do
  half = CHUNKS.each_slice(2).to_a
  threads = half.map { |pairs| Thread.new { pairs.each { |lo, hi| count_primes(lo, hi) } } }
  threads.each(&:join)
end

measure("thread x4") do
  threads = CHUNKS.map { |lo, hi| Thread.new { count_primes(lo, hi) } }
  threads.each(&:join)
end

measure("ractor x4") do
  ractors = CHUNKS.map { |lo, hi| Ractor.new(lo, hi) { |l, h| count_primes(l, h) } }
  ractors.each(&:value)
end
