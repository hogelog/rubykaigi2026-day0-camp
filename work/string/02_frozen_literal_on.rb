# frozen_string_literal: true
#
# 02a: frozen string literal: true の状態で、リテラル文字列をループで評価したら
# どのくらい String オブジェクトが増えるか。frozen 時は同じリテラルは
# 同じオブジェクト(object_id が共有) になる想定。

GC.start
GC.disable

before = ObjectSpace.count_objects[:T_STRING]
ids = []
1_000.times do
  s = "hello world"          # リテラル
  ids << s.object_id
end
after = ObjectSpace.count_objects[:T_STRING]

puts "frozen_string_literal: true"
puts "  literal.frozen?           = #{"hello world".frozen?}"
puts "  T_STRING increased        = #{after - before}"
puts "  unique object_ids in 1000 = #{ids.uniq.size}"
puts "  sample object_ids         = #{ids.first(3).inspect}"
