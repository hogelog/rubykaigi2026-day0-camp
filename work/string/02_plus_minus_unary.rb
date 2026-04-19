# frozen_string_literal: false
#
# 02d: String#+@ (unfrozen copy) と #-@ (frozen な共有コピー) の挙動。
# "foo".-@ は同じ内容の frozen な共有文字列を返す(interning)。

s = "hello"
frozen = -s
mutable = +frozen

puts "source           : id=#{s.object_id}  frozen?=#{s.frozen?}"
puts "-s (interned)    : id=#{frozen.object_id}  frozen?=#{frozen.frozen?}"
puts "+frozen (unfroze): id=#{mutable.object_id}  frozen?=#{mutable.frozen?}"
puts

a = -"shared"
b = -"shared"
puts "-\"shared\" は同じ id?  => #{a.object_id == b.object_id}"
puts "  a.object_id = #{a.object_id}"
puts "  b.object_id = #{b.object_id}"
puts

c = +"mutable"
d = +"mutable"
puts "+\"mutable\" は同じ id? => #{c.object_id == d.object_id}"
puts "  c.object_id = #{c.object_id}"
puts "  d.object_id = #{d.object_id}"
