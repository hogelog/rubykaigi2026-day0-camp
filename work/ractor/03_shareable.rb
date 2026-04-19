# frozen_string_literal: true

# Ractor 入門3: 何が shareable で何がそうでないか、make_shareable で何が変わるか。

Warning[:experimental] = false

SAMPLES = {
  "nil" => nil,
  "true" => true,
  "1" => 1,
  "1.5" => 1.5,
  ":sym" => :sym,
  '"literal" (frozen)' => "frozen literal string",
  "+\"dyn\" (unfrozen)" => +"dynamic",
  "[1,2,3]" => [1, 2, 3],
  "[1,2,3].freeze" => [1, 2, 3].freeze,
  "[[1]].freeze (inner unfrozen)" => [[1]].freeze,
  "{a:1}" => { a: 1 },
  "{a:1}.freeze" => { a: 1 }.freeze,
  "Object.new" => Object.new,
  "Object.new.freeze" => Object.new.freeze,
  "1..10 (Range)" => (1..10),
  "->{}" => -> {},
  "Mutex.new" => Mutex.new,
}

printf "%-32s %-10s %-10s\n", "value", "frozen?", "shareable?"
SAMPLES.each do |label, v|
  printf "%-32s %-10s %-10s\n", label, v.frozen?.to_s, Ractor.shareable?(v).to_s
end

puts
puts "-- make_shareable の効果 --"
nested = [[1, 2], { a: [3, 4] }]
puts "before: frozen?=#{nested.frozen?}, inner[0].frozen?=#{nested[0].frozen?}, inner[1][:a].frozen?=#{nested[1][:a].frozen?}"
Ractor.make_shareable(nested)
puts "after : frozen?=#{nested.frozen?}, inner[0].frozen?=#{nested[0].frozen?}, inner[1][:a].frozen?=#{nested[1][:a].frozen?}"
puts "shareable? = #{Ractor.shareable?(nested)}"

puts
puts "-- make_shareable できない例 --"
begin
  m = Mutex.new
  Ractor.make_shareable(m)
  puts "Mutex: unexpectedly succeeded, shareable?=#{Ractor.shareable?(m)}"
rescue => e
  puts "Mutex: #{e.class}: #{e.message}"
end

begin
  outer = "hello"
  p = -> { outer }
  Ractor.make_shareable(p)
  puts "closure proc: unexpectedly succeeded"
rescue => e
  puts "closure proc: #{e.class}: #{e.message.lines.first.chomp}"
end

puts
puts "-- copy: true で「コピーは shareable に」 --"
arr = [1, 2, 3]
shared = Ractor.make_shareable(arr, copy: true)
puts "original frozen?=#{arr.frozen?}, copy frozen?=#{shared.frozen?}"
puts "same object? = #{arr.equal?(shared)}"
