# frozen_string_literal: false
#
# 02b: frozen string literal: false の状態。
# 同じリテラルでも評価のたびに新しい String が作られるはず。

GC.start
GC.disable

before = ObjectSpace.count_objects[:T_STRING]
ids = []
1_000.times do
  s = "hello world"
  ids << s.object_id
end
after = ObjectSpace.count_objects[:T_STRING]

puts "frozen_string_literal: false"
puts "  literal.frozen?           = #{"hello world".frozen?}"
puts "  T_STRING increased        = #{after - before}"
puts "  unique object_ids in 1000 = #{ids.uniq.size}"
puts "  sample object_ids         = #{ids.first(3).inspect}"
