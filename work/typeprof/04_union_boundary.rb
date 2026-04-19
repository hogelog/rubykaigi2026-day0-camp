# frozen_string_literal: true

# typeprof 0.31 が「推論できる」範囲の境界を探る。
# 戻り値ユニオン、引数ユニオン、nil 合流、Array の要素ユニオン、Hash の値型、など。

# (a) 条件分岐で戻り値が Integer | String | nil
def pick(kind)
  case kind
  when :int then 1
  when :str then "one"
  else nil
  end
end

# (b) 同じ関数を複数の型で呼ぶと引数はユニオンになるか?
def identity(x) = x

# (c) 配列の要素が混ざると Array[union] になるか
def mixed_array
  [1, "two", :three, nil]
end

# (d) Hash の値の型
def simple_hash
  { a: 1, b: "two" }
end

# (e) メソッドチェイン越しの nil 伝播
def maybe_upcase(s)
  s&.upcase
end

# (f) early return による複数 return 地点の合成
def classify(n)
  return :zero if n.zero?
  return :neg if n.negative?
  :pos
end

# (g) リテラル値の伝播 - TypeProf はリテラル型を保持する?
def literal_chain
  x = 10
  x + 1
end

# (h) ブロックを受けるメソッド
def yielder(x)
  yield x
end

# 呼び出し側 - TypeProf に実行経路を示す
pick(:int)
pick(:str)
pick(:other)

identity(1)
identity("two")
identity(:three)
identity([1, 2])

mixed_array
simple_hash

maybe_upcase("hi")
maybe_upcase(nil)

classify(1)
classify(-1)
classify(0)

literal_chain

yielder(3) { |v| v * 2 }
yielder("x") { |s| s.length }
