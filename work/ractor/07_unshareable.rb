# frozen_string_literal: true

# Ractor 上級: 共有できない値を Ractor.new の引数や #send で渡したときに
# どんなエラーが出るかを種類別に眺める。
#
# 送る前(main)での失敗と、受け側 Ractor 内での失敗の境界も見る。

Warning[:experimental] = false

def show(label)
  yield
  puts "#{label}: OK (何らかの形で通った)"
rescue => e
  msg = e.message.lines.first.to_s.chomp
  puts "#{label}: #{e.class}: #{msg}"
end

puts "Ruby: #{RUBY_DESCRIPTION}"
puts

# (a) Mutex を send: コピーもできないタイプ
show("(a) send Mutex") do
  r = Ractor.new { Ractor.receive }
  r.send(Mutex.new)
  r.value
end

# (b) STDOUT (IO) を send: shareable だが書き込み競合リスク
show("(b) send STDOUT") do
  r = Ractor.new { Ractor.receive.class.to_s }
  r.send(STDOUT)
  r.value
end

# (c) クロージャを持つ Proc を send
show("(c) send closure proc") do
  outer = "hello"
  p = -> { outer }
  r = Ractor.new { Ractor.receive.call }
  r.send(p)
  r.value
end

# (d) Ractor.make_shareable 済みの純粋関数 Proc を send
show("(d) send shareable proc") do
  pure = Ractor.make_shareable(->(x) { x * 2 })
  r = Ractor.new { Ractor.receive.call(21) }
  r.send(pure)
  r.value
end

# (e) ivar に非 shareable を抱えるオブジェクトを send
class Box
  def initialize(payload)
    @payload = payload
  end
  attr_reader :payload
end

show("(e) send Box with Array ivar (copy)") do
  r = Ractor.new do
    box = Ractor.receive
    [box.payload, box.payload.frozen?]
  end
  b = Box.new([1, 2, 3])
  r.send(b)
  p r.value
end

show("(f) send Box with Mutex ivar") do
  r = Ractor.new { Ractor.receive }
  r.send(Box.new(Mutex.new))
  r.value
end

# (g) self を参照する Proc(trueish な closure)
show("(g) send instance_eval-ish proc") do
  p = method(:puts).to_proc
  r = Ractor.new { Ractor.receive.call("hi from ractor") }
  r.send(p)
  r.value
end

# (h) 無限ループの Thread を抱えた値 — Thread 自体は send できるのか?
show("(h) send a Thread") do
  t = Thread.new { sleep 0.01; :done }
  r = Ractor.new { Ractor.receive.class.to_s }
  r.send(t)
  r.value
end
