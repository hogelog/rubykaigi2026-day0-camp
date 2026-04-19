# frozen_string_literal: true

# 基本的な Ruby の機能を一通り混ぜた小さなサンプル。
# typeprof にかけて出力される RBS を読む題材。
#
# 走らせる例:
#   $ ruby work/typeprof/01_basic.rb
#   $ typeprof work/typeprof/01_basic.rb

# 単純な関数: Integer を受けて Integer を返す
def double(x)
  x * 2
end

# 引数の型が違って結果が変わる例
def greet(name, loud: false)
  msg = "hello, #{name}"
  loud ? msg.upcase : msg
end

# 戻り値が分岐するケース: nil を含むユニオン
def find_even(nums)
  nums.find { |n| n.even? }
end

# Array / Hash を触る
def histogram(words)
  words.each_with_object(Hash.new(0)) do |w, h|
    h[w] += 1
  end
end

# クラス + attr_accessor + 状態
class Counter
  attr_reader :count

  def initialize(start = 0)
    @count = start
  end

  def add(n)
    @count += n
    self
  end

  def reset
    @count = 0
    nil
  end
end

# クラス + 継承、override
class ShoutCounter < Counter
  def add(n)
    super(n.abs)
  end
end

# main 相当 (TypeProf に実行経路を示す)
puts double(3)
puts greet("world")
puts greet("rubyists", loud: true)
p find_even([1, 3, 5])
p find_even([1, 2, 3])
p histogram(%w[a b a c a b])

c = Counter.new
c.add(1).add(2)
puts c.count

sc = ShoutCounter.new(10)
sc.add(-5)
puts sc.count
