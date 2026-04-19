# frozen_string_literal: true
#
# 06: RString の Embedded / Heap 境界を ObjectSpace.memsize_of で探る
#
# RString は短い文字列を構造体内部に埋め込む (embedded)。境界を超えると
# ヒープ上の別バッファを確保する (heap)。memsize_of は「この String が
# 占めている総メモリ」を返すので、長さを増やしていくと embedded → heap
# への切替で値がジャンプする。
#
# Ruby 4.0.2 (PRISM, x86_64-linux-gnu) で観察。
# USE_RVARGC / VWA が有効な最近の Ruby では、heap 側もサイズに応じた
# bin に割り当てられるため、きれいな 1 段のジャンプではなく段階的に
# 増える場合もある。

require "objspace"

puts "RUBY_DESCRIPTION: #{RUBY_DESCRIPTION}"
puts

printf "%5s  %10s  %10s  %s\n", "len", "bytesize", "memsize_of", "delta"
prev = nil
results = []
lens = [0, 1, 4, 8, 12, 16, 20, 22, 23, 24, 25, 28, 32, 40, 48, 64, 80, 96, 128, 256, 512, 1024]
lens.each do |n|
  # 非 frozen な ASCII 文字列を作る
  s = +("a" * n)
  size = ObjectSpace.memsize_of(s)
  delta = prev ? size - prev : 0
  results << [n, s.bytesize, size, delta]
  printf "%5d  %10d  %10d  %+d\n", n, s.bytesize, size, delta
  prev = size
end

puts
puts "== 観察 =="
embed_limit = results.find { |(_, _, sz, d)| d > 0 && results.first[2] == results[1][2] }
first_heap = results.find { |(_, _, _, d)| d > 0 }
if first_heap
  puts "  * memsize_of が最初に増える長さ: #{first_heap[0]} bytes"
  puts "    -> ここが embedded ⇒ heap 切替の候補"
end

puts
puts "== 追加実験: dup と -@ と frozen literal のメモリ =="
base = "x" * 64
puts "  base                  memsize_of=#{ObjectSpace.memsize_of(base)}"
puts "  base.dup              memsize_of=#{ObjectSpace.memsize_of(base.dup)}"
puts "  -base (interned)      memsize_of=#{ObjectSpace.memsize_of(-base)}"
puts "  +base (unfrozen copy) memsize_of=#{ObjectSpace.memsize_of(+base)}"

puts
puts "== 部分文字列の共有 =="
big = "a" * 1024
part = big[0, 500]
puts "  big  memsize_of = #{ObjectSpace.memsize_of(big)}"
puts "  part = big[0, 500]: memsize_of = #{ObjectSpace.memsize_of(part)}"
puts "  (小さい値なら heap バッファを共有している可能性が高い)"

puts
puts "== 参考: RSTRING_EMBED_LEN_MAX 相当 =="
puts "  string.h / rstring.h では 64-bit 環境で embed 可能な最大長は"
puts "  概ね 23 バイト程度(構造体の内側にすっぽり収まる範囲)。"
puts "  memsize_of の最初のジャンプがその境界を教えてくれる。"
