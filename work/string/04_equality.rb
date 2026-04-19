# frozen_string_literal: true
#
# 04: == / eql? / equal? / hash の関係
#
# Ruby の等価性:
#   equal?  : object_id が同じ(同一オブジェクト)。基本的にオーバーライド禁止
#   ==      : 「値」が等しい。型をまたいで true になることがある
#   eql?    : 「値」が等しく、型(クラス/エンコーディングなど)も揃っている
#   hash    : eql? な値は同じ hash を返さないと Hash キーが壊れる

def row(label, a, b)
  puts "  #{label.ljust(32)} a==b=#{(a == b).to_s.ljust(5)}  " \
       "a.eql?(b)=#{(a.eql?(b)).to_s.ljust(5)}  " \
       "a.equal?(b)=#{(a.equal?(b)).to_s.ljust(5)}  " \
       "hash一致=#{(a.hash == b.hash).to_s.ljust(5)}"
end

puts "== 基本 =="
row("同じリテラル", "hello", "hello")
row("同じ内容の別リテラル", "abc", +"abc")

puts
puts "== Encoding が違う =="
utf8 = "abc".encode("UTF-8")
ascii = "abc".encode("US-ASCII")
row("UTF-8 vs US-ASCII (ascii-only)", utf8, ascii)
# ASCII-only な場合は encoding をまたいでも等価扱い

utf8_ja = "日本"
sjis_ja = "日本".encode("Shift_JIS")
row("UTF-8 vs Shift_JIS (non-ascii)", utf8_ja, sjis_ja)

puts
puts "== String と Symbol =="
row("\"foo\" と :foo", "foo", :foo)
# Symbol と String は == も eql? も false

puts
puts "== NFC と NFD の é =="
nfc = "\u00E9"       # "é" 1 コードポイント
nfd = "e\u0301"      # "e" + 結合文字
row("NFC é vs NFD é", nfc, nfd)
# 表示は同じでもバイトが違うので全て false
puts "  → 表示は同じなのに == も eql? も false。"
puts "    見た目で一致判定したいときは unicode-normalize gem の String#unicode_normalize が必要。"

puts
puts "== Hash キーとして使う =="
h = { "key" => 1 }
sjis_key = "key".encode("Shift_JIS")
puts "  h[\"key\"]             = #{h['key'].inspect}"
puts "  h[sjis_key]            = #{h[sjis_key].inspect}  # ascii-only なので拾える"

ja_utf8 = "日本"
h2 = { ja_utf8 => 1 }
ja_sjis = "日本".encode("Shift_JIS")
puts "  h2[UTF-8 '日本']      = #{h2[ja_utf8].inspect}"
puts "  h2[Shift_JIS '日本']  = #{h2[ja_sjis].inspect}  # hash が違うので引けない"

puts
puts "== frozen な文字列も同じ扱い =="
a = "same"
b = "same".dup.freeze
row("frozen vs unfrozen", a, b)
puts "  → frozen かどうかは == も eql? も無視する"
