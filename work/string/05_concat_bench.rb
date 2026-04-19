# frozen_string_literal: true
#
# 05: 文字列連結の方式と性能差
#
# 比較対象:
#   a + b          : 新しい String を返す非破壊。一時オブジェクトが増える
#   a << b         : 破壊的。a に直接書き込む
#   a.concat(b)    : << と同義の破壊的連結
#   a += b         : a = a + b の糖衣。一時 String を生成して再代入
#   format("%s%s") : sprintf 風の構築
#   [a, b].join    : 配列ベースの構築
#
# ループで「N 個のパーツを連結して 1 本の文字列にする」ケースで比較する。

require "benchmark"

N = 10_000
parts = Array.new(N) { "x" * 16 }.freeze

GC.start

# warmup: 最初の測定が JIT や page fault の影響を受けるのでダミー実行する
Array.new(N) { "x" * 16 }.each { |_| }
5.times { (+"").tap { |s| 1_000.times { s << "x" } } }

def measure(label, &block)
  GC.start
  GC.disable
  before_strings = ObjectSpace.count_objects[:T_STRING]
  t = Benchmark.realtime(&block)
  after_strings = ObjectSpace.count_objects[:T_STRING]
  GC.enable
  printf "  %-24s %8.2f ms   T_STRING=%+d\n",
         label, t * 1000, after_strings - before_strings
end

puts "N = #{N}, part size = 16 bytes"
puts "最終的な String のサイズ = #{N * 16} bytes"

measure("a + b (非破壊)") do
  s = +""
  parts.each { |p| s = s + p }
  s.length
end

measure("a += b") do
  s = +""
  parts.each { |p| s += p }
  s.length
end

measure("a << b (破壊)") do
  s = +""
  parts.each { |p| s << p }
  s.length
end

measure("a.concat(b)") do
  s = +""
  parts.each { |p| s.concat(p) }
  s.length
end

measure("Array#join") do
  parts.join
end

measure("format ('%s' * N)") do
  format("%s" * N, *parts)
end

measure("String#+ チェーン (pair)") do
  # a+b+c+d+... は左結合なので内部的にはループと同じ
  parts.reduce(+"") { |acc, p| acc + p }
end

puts
puts "結論的なスケール感:"
puts "  + / += は毎回 'acc の全バイトをコピー' するので O(N^2)。"
puts "  << や concat は末尾に追加するだけなので O(N)。"
puts "  Array#join は内部で 1 回バッファを確保して書き込むので軽い。"
