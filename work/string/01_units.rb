# 01: 文字列をどの「単位」で数えるか
#
# bytes / chars / codepoints / grapheme_clusters の違いを
# ASCII・日本語・絵文字(ZWJ 合字・skin tone modifier)で横並びに観察する。

def inspect_units(label, str)
  puts "-" * 60
  puts "#{label}: #{str.inspect}  (encoding=#{str.encoding})"
  puts "  bytesize            = #{str.bytesize}"
  puts "  length (= chars)    = #{str.length}"
  puts "  codepoints.size     = #{str.codepoints.size}"
  puts "  grapheme_clusters   = #{str.grapheme_clusters.size}"
  puts "  bytes               = #{str.bytes.inspect}"
  puts "  codepoints (hex)    = #{str.codepoints.map { |c| format('U+%04X', c) }.inspect}"
  puts "  grapheme_clusters   = #{str.grapheme_clusters.inspect}"
end

inspect_units("ASCII      ", "hello")
inspect_units("日本語      ", "日本語")
inspect_units("絵文字(顔) ", "😀")
# 家族絵文字: 👨 + ZWJ + 👩 + ZWJ + 👧 + ZWJ + 👦 (7 コードポイントで 1 グラフェム)
inspect_units("ZWJ family ", "👨\u200D👩\u200D👧\u200D👦")
# 肌色修飾: 👋🏽 は base + modifier の 2 コードポイントで 1 グラフェム
inspect_units("skin tone  ", "👋🏽")
# 結合文字: é は U+00E9 (1cp) のものと、U+0065 + U+0301 (2cp) のものがある
inspect_units("NFC  é     ", "\u00E9")
inspect_units("NFD  é     ", "e\u0301")
