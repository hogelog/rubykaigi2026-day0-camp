# frozen_string_literal: true

# Ractor 中級1: Ruby 4.0 で旧 API (take / yield / receive_if) が消えている
# ことを実際に突いて確かめ、新 API (Port / #join / #value) への置き換えを示す。

Warning[:experimental] = false

puts "Ruby: #{RUBY_DESCRIPTION}"
puts

# 旧 API 群。それぞれ存在チェック。
puts "-- メソッドの有無 --"
r = Ractor.new { 42 }
r.join

old_instance_methods = %i[take]
old_class_methods = %i[yield receive_if]
new_port_class_methods = %i[select] # 念のため(環境により廃止/残置が揺れていた時期があった)

old_instance_methods.each do |m|
  puts "  Ractor##{m}: #{Ractor.instance_method(m) rescue "NOT DEFINED (#{$!.class})"}"
end
old_class_methods.each do |m|
  puts "  Ractor.#{m}: #{Ractor.method(m) rescue "NOT DEFINED (#{$!.class})"}"
end
new_port_class_methods.each do |m|
  puts "  Ractor.#{m}: #{Ractor.method(m) rescue "NOT DEFINED (#{$!.class})"}"
end

puts
puts "-- 新 API: Ractor::Port --"
puts "  Ractor::Port defined? #{defined?(Ractor::Port) ? "yes" : "NO"}"
puts "  Port instance methods: #{Ractor::Port.instance_methods(false).sort.inspect}"

puts
puts "-- 旧 パターン → 新 パターンの書き換え --"

# (旧)  r = Ractor.new { compute }; result = r.take
# (新)  r = Ractor.new { compute }; result = r.value
worker = Ractor.new do
  (1..1_000).sum
end
puts "  r.value (旧 r.take の代わり): #{worker.value}"

# (旧) producer: Ractor.yield(x) を繰り返し / main: r.take で拾う
# (新) producer: port.send(x) / consumer: port.receive
port = Ractor::Port.new
producer = Ractor.new(port) do |p|
  3.times { |i| p.send("msg##{i}") }
  p.send(:done)
end

loop do
  msg = port.receive
  puts "  port.receive → #{msg.inspect}"
  break if msg == :done
end
producer.join
