# frozen_string_literal: true

# Ractor 入門1: 2〜3 個の Ractor で挨拶し合う最小例。
# Ruby 4.0 では `Ractor::Port` / `Ractor#value` / `Ractor#join` が前提。
# 旧 `Ractor#take` / `Ractor.yield` は削除されている。

Warning[:experimental] = false # experimental 警告を一旦黙らせる

puts "Ruby: #{RUBY_DESCRIPTION}"
puts "-" * 60

# (a) 一番素直: 受け取った値をそのまま返す Ractor
greeter = Ractor.new do
  name = Ractor.receive                 # 外からのメッセージを待つ
  "Hello, #{name}, from #{Ractor.current.inspect}"
end

greeter.send("camper")                  # 送信。Ractor#send または << が使える
greeter.join                            # 終了待ち
puts "value: #{greeter.value.inspect}"

puts

# (b) 3 個の Ractor が自分の ID を返して、main で集計する
ractors = 3.times.map do |i|
  Ractor.new(i) do |idx|                # Ractor.new の引数でオブジェクトを copy 渡し
    "##{idx} from #{Ractor.current.object_id}"
  end
end

greetings = ractors.map(&:value)        # #value は内部で終了まで待つ
greetings.each { |g| puts g }
