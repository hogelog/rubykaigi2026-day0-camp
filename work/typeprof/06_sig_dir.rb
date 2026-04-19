# frozen_string_literal: true

# sig/ ディレクトリに RBS を置く「伝統的な」流儀で TypeProf を走らせる。
# 05 は Ruby ファイル中の #: で書いたが、こちらはファイルを分ける流儀。

class Calculator
  def add(a, b)
    a + b
  end

  def divide(a, b)
    a / b
  end
end

c = Calculator.new
c.add(1, 2)
c.divide(10, 0) # TypeProf はゼロ除算を知らないので型的には OK
c.add("oops", 2) # 型エラーを期待
