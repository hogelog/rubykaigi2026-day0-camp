# frozen_string_literal: true

# Ractor 入門2: 外側のローカル変数をキャプチャしようとしたときのエラーを読む。

Warning[:experimental] = false

def show(label)
  yield
  puts "#{label}: OK"
rescue => e
  puts "#{label}: #{e.class}: #{e.message.lines.first.chomp}"
end

# (a) 外のローカル変数を Ractor ブロックから参照 → 生成時にエラー
show("(a) outer local capture") do
  name = "camper"
  Ractor.new do
    # name を参照したいだけ。Ractor は外の local に触れない。
    puts name # rubocop:disable Lint/UselessAssignment
  end
end

# (b) 引数経由で渡す → OK
show("(b) pass via argument") do
  name = "camper"
  r = Ractor.new(name) { |n| "hello #{n}" }
  r.join
end

# (c) 外のブロックローカルの「定数」も見えない: トップレベル定数は可、self.class は不可
MESSAGE = "frozen literal constant"
show("(c) top-level frozen constant") do
  r = Ractor.new { MESSAGE }
  raise "unexpected: #{r.value.inspect}" unless r.value == MESSAGE
end

NON_SHAREABLE = []
show("(d) non-shareable constant") do
  r = Ractor.new { NON_SHAREABLE }
  r.value
end

# (e) send で渡す: 既定は deep-copy
show("(e) send copies deeply") do
  arr = [1, 2, 3]
  r = Ractor.new do
    received = Ractor.receive
    received << :appended
    received
  end
  r.send(arr)
  copied = r.value
  # 受け側で << したが、送り側 arr は変わっていない = copy だった
  raise "copy failed: arr=#{arr.inspect}" unless arr == [1, 2, 3]
  raise "received weird: #{copied.inspect}" unless copied == [1, 2, 3, :appended]
end

# (f) move: true で所有権移動。元は「moved」状態になり触ると例外
show("(f) send(move: true) invalidates sender-side") do
  arr = [1, 2, 3]
  r = Ractor.new do
    Ractor.receive
  end
  r.send(arr, move: true)
  r.join
  arr.size # ここで例外になるはず
end
