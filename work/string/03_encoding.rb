# frozen_string_literal: true
#
# 03: Encoding と Encoding::Converter を触る。
# - UTF-8 → Shift_JIS → UTF-8 で往復すると何が起きるか
# - UTF-16BE / LE、BOM 付き UTF-16 の byte 表現
# - force_encoding と encode の違い
# - ASCII-8BIT との付き合い方

def dump_bytes(label, str)
  hex = str.bytes.map { |b| format('%02X', b) }.join(' ')
  puts "  #{label.ljust(28)} enc=#{str.encoding.to_s.ljust(10)} " \
       "bytesize=#{str.bytesize.to_s.rjust(3)}  bytes=[#{hex}]"
end

s = "日本語 Ruby"
puts "== source (UTF-8) =="
dump_bytes("original", s)

puts
puts "== encode: UTF-8 → Shift_JIS → UTF-8 =="
sjis = s.encode("Shift_JIS")
dump_bytes("→ Shift_JIS", sjis)
back = sjis.encode("UTF-8")
dump_bytes("→ UTF-8 (round-trip)", back)
puts "  round-trip =="
puts "  ==? #{s == back}"

puts
puts "== encode: UTF-8 → UTF-16BE / UTF-16LE / UTF-16 (BOM) =="
dump_bytes("→ UTF-16BE", s.encode("UTF-16BE"))
dump_bytes("→ UTF-16LE", s.encode("UTF-16LE"))
dump_bytes("→ UTF-16 (default BOM=BE)", s.encode("UTF-16"))
dump_bytes("→ UTF-16 (BOM)", s.encode("UTF-16"))

puts
puts "== force_encoding vs encode =="
raw = "\xE6\x97\xA5\xE6\x9C\xAC" # UTF-8 で「日本」の生バイト列
raw_ascii = raw.dup.force_encoding("ASCII-8BIT")
dump_bytes("raw (ASCII-8BIT)", raw_ascii)
forced = raw_ascii.dup.force_encoding("UTF-8")
dump_bytes("force_encoding → UTF-8", forced)
puts "  valid_encoding?=#{forced.valid_encoding?}  as string=#{forced.inspect}"

begin
  encoded = raw_ascii.dup.encode("UTF-8", "ASCII-8BIT")
  dump_bytes("encode ASCII-8BIT→UTF-8", encoded)
rescue Encoding::UndefinedConversionError => e
  puts "  encode(UTF-8, ASCII-8BIT) は例外: #{e.class}"
  puts "    message: #{e.message}"
  puts "  ASCII-8BIT 側に 0x80..0xFF のバイトがあると UTF-8 への変換は失敗する"
  puts "  (ASCII 範囲外のバイトが「どの文字」に対応するか定義されていないため)"
  puts "  → 生バイトをそのまま UTF-8 として解釈したいなら force_encoding を使う"
end

puts
puts "== 変換不能文字: Shift_JIS にない文字 =="
emoji = "Ruby 😀"
begin
  emoji.encode("Shift_JIS")
rescue Encoding::UndefinedConversionError => e
  puts "  raised: #{e.class}: #{e.message}"
end
replaced = emoji.encode("Shift_JIS", undef: :replace, replace: "?")
dump_bytes("→ Shift_JIS (undef→?)", replaced)

puts
puts "== Encoding::Converter で 2 段変換 (UTF-8 → UTF-16BE with BOM) =="
ec = Encoding::Converter.new("UTF-8", "UTF-16", universal_newline: true)
converted = ec.convert("hello\n日本語\n")
dump_bytes("UTF-16 (Converter)", converted)
puts "  先頭 2 バイトが BOM (FE FF) で始まっていれば UTF-16BE 扱い"
