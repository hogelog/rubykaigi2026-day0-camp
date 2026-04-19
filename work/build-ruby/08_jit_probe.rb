# frozen_string_literal: true

# master でビルドした ruby の YJIT / ZJIT が本当にコード生成まで走るかを確かめる。
# 呼び出し側 08_jit_probe.sh が interpreter / --yjit --yjit-stats / --zjit --zjit-stats の
# 3 通りでこのファイルを回す。stats はそれぞれのフラグが付いている時だけ中身が入る。

FIB_N = 35  # ~10M 再帰呼び出し。JIT の compile overhead を相対的に小さくする。

def fib(n)
  return n if n < 2
  fib(n - 1) + fib(n - 2)
end

mode =
  if RubyVM::YJIT.enabled?
    "YJIT"
  elsif RubyVM::ZJIT.enabled?
    "ZJIT"
  else
    "interp"
  end

t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
value = fib(FIB_N)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0

printf "%-6s  fib(%d)=%d  %.3fs\n", mode, FIB_N, value, elapsed

case mode
when "YJIT"
  stats = RubyVM::YJIT.runtime_stats
  if stats
    %i[compiled_iseq_count compiled_block_count compiled_branch_count
       yjit_insns_count side_exit_count].each do |k|
      puts "  #{k}: #{stats[k]}" if stats.key?(k)
    end
  else
    puts "  (no runtime_stats; pass --yjit-stats)"
  end
when "ZJIT"
  stats = RubyVM::ZJIT.stats
  if stats && !stats.empty?
    stats.first(8).each { |k, v| puts "  #{k}: #{v}" }
  else
    puts "  (no stats; pass --zjit-stats or --zjit-stats-quiet)"
  end
end
