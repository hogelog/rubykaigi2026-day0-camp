# frozen_string_literal: true

# TypeProf v0.30+ の "#: シグネチャ" アノテーション機能を試す。
# (mame の RubyKaigi 2025 "Writing Ruby Scripts with TypeProf" で紹介された、
# Ruby コードに直接 RBS を書いて型チェックさせる流儀)

# (A) 宣言通りに使う: 型が合うので通るはず
#: (Integer, Integer) -> Integer
def add(a, b)
  a + b
end

add(1, 2)

# (B) 宣言に違反: 引数に String を渡す
#: (Integer) -> Integer
def square(x)
  x * x
end

square(3)
square("oops") # ここで型エラーが出てほしい

# (C) 宣言 (String) -> Integer なのに本体が String を返す
#: (String) -> Integer
def length_or_lie(s)
  s # 本当は Integer ではなく String を返している
end

length_or_lie("abc")

# (D) アノテーション無しのメソッドは従来通り推論される
def untagged(x)
  x.to_s
end

untagged(42)

# (E) キーワード引数とオプショナル
#: (String, ?loud: bool) -> String
def greet(name, loud: false)
  loud ? "HEY #{name.upcase}" : "hi #{name}"
end

greet("alice")
greet("bob", loud: true)
greet("carol", loud: "truthy") # bool 以外を渡した

# (F) ブロック付き
#: (Array[Integer]) { (Integer) -> Integer } -> Array[Integer]
def map_ints(xs, &blk)
  xs.map(&blk)
end

map_ints([1, 2, 3]) { |n| n * 2 }
map_ints([1, 2, 3]) { |n| n.to_s } # ブロックの戻り値が違う
