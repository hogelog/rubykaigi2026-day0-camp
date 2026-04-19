# frozen_string_literal: true
#
# 02c: frozen_string_literal: true でも、式展開 ("#{...}") を含むリテラルは
# 評価のたびに新しい String になる。これは直感に反するので手で確かめる。
# 参考: https://docs.ruby-lang.org/ja/latest/doc/pragma.html

GC.start
GC.disable

name = "world"
ids = []
1_000.times do
  s = "hello #{name}"
  ids << s.object_id
end

puts "frozen_string_literal: true, with interpolation"
puts "  literal.frozen?           = #{"hello #{name}".frozen?}"
puts "  unique object_ids in 1000 = #{ids.uniq.size}"
puts "  sample object_ids         = #{ids.first(3).inspect}"
