# frozen_string_literal: true

# typeprof の推論が「諦める/untyped に落ちる/自信を持って出せない」ケースを並べる。
# 入口は全部 Foo.<method> か、各 def を直接呼ぶ形で TypeProf に実行経路を示す。

# (a) define_method で動的に生やす
class DynamicMethods
  %i[ping pong pang].each do |name|
    define_method(name) { name.to_s }
  end
end

# (b) method_missing で応える擬似オブジェクト
class StringyMissing
  def method_missing(name, *args)
    "you called #{name} with #{args.inspect}"
  end

  def respond_to_missing?(_name, _include_private = false) = true
end

# (c) send / public_send で間接呼び出し
class Dispatcher
  def greet(name) = "hi, #{name}"

  def call(method_name, arg)
    send(method_name, arg)
  end
end

# (d) Duck typing: respond_to? で分岐
def read_size(obj)
  if obj.respond_to?(:size)
    obj.size
  else
    -1
  end
end

# (e) Struct で定義したクラス
Point = Struct.new(:x, :y) do
  def distance_from_origin
    Math.sqrt(x * x + y * y)
  end
end

# (f) Data.define (Ruby 3.2+)
RGB = Data.define(:r, :g, :b) do
  def luminance
    0.299 * r + 0.587 * g + 0.114 * b
  end
end

# main
DynamicMethods.new.ping
DynamicMethods.new.pong
DynamicMethods.new.pang

StringyMissing.new.whatever(1, 2)
StringyMissing.new.respond_to?(:foo)

d = Dispatcher.new
d.call(:greet, "alice")

read_size("hello")
read_size([1, 2, 3])
read_size(42)

p = Point.new(3, 4)
p.distance_from_origin

c = RGB.new(128, 200, 64)
c.luminance
