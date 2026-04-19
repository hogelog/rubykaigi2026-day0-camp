# frozen_string_literal: true

# Ractor 中級2: CPU バウンドな処理(素数カウント)を serial / Thread / Ractor で
# 並列化してスループットを比較する。GVL の影響を目で見る。

require "benchmark"

Warning[:experimental] = false

puts "Ruby: #{RUBY_DESCRIPTION}"
puts "nproc: #{Etc.nprocessors}" if defined?(Etc) || (require "etc" and true)
puts

# 判定を共有オブジェクトなしの純 Ruby で閉じるため、トップレベルに置く。
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

# 4 分割できる範囲で、それなりに重い仕事量
TOTAL_RANGE = 2..400_000
WORKERS = 4
CHUNK = ((TOTAL_RANGE.max - TOTAL_RANGE.min) / WORKERS.to_f).ceil
CHUNKS = WORKERS.times.map do |i|
  lo = TOTAL_RANGE.min + i * CHUNK
  hi = [lo + CHUNK - 1, TOTAL_RANGE.max].min
  [lo, hi]
end
puts "chunks: #{CHUNKS.inspect}"

def bench(label)
  3.times { yield } # warmup
  GC.start
  t = Benchmark.realtime { yield }
  printf "%-14s %.3f sec\n", label, t
end

expected = count_primes(TOTAL_RANGE.min, TOTAL_RANGE.max)
puts "expected prime count: #{expected}"
puts

# --- serial ---
bench("serial") do
  sum = 0
  CHUNKS.each { |lo, hi| sum += count_primes(lo, hi) }
  raise "mismatch: #{sum}" unless sum == expected
end

# --- Thread ---
bench("thread x#{WORKERS}") do
  threads = CHUNKS.map { |lo, hi| Thread.new { count_primes(lo, hi) } }
  sum = threads.map(&:value).sum
  raise "mismatch: #{sum}" unless sum == expected
end

# --- Ractor ---
bench("ractor x#{WORKERS}") do
  ractors = CHUNKS.map { |lo, hi| Ractor.new(lo, hi) { |l, h| count_primes(l, h) } }
  sum = ractors.map(&:value).sum
  raise "mismatch: #{sum}" unless sum == expected
end
