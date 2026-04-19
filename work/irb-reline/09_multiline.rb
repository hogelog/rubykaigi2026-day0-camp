# frozen_string_literal: true
#
# Reline.readmultiline + auto_indent_proc のデモ。
# 入力を「def/if/do が出たらインデント深くし、end で浅くする」で追跡する
# ミニ言語 (BALANCE) を書き、IRB のマルチライン編集の簡易版を体感する。
#
# 実行: ruby work/irb-reline/09_multiline.rb

require "reline"

OPEN  = /\b(def|class|module|if|unless|while|until|case|begin|do)\b(?!.*\bend\b)/.freeze
CLOSE = /\bend\b/.freeze

def depth_of(lines, upto)
  d = 0
  lines[0..upto].each do |ln|
    d += ln.scan(OPEN).size
    d -= ln.scan(CLOSE).size
  end
  [d, 0].max
end

LOG = ENV["INDENT_LOG"] ? File.open(ENV["INDENT_LOG"], "a") : nil
LOG&.sync = true
LOG&.puts "[boot] reline=#{Reline::VERSION} tty=#{STDIN.tty?} env=#{ENV['INDENT_LOG']}"

# 各行の先頭インデント量(スペース 2 個単位)を返す
Reline.auto_indent_proc = ->(lines, line_index, byte_pointer, is_newline) do
  indent =
    if line_index == 0
      0
    else
      prev_depth = depth_of(lines, line_index - 1)
      cur_line   = lines[line_index].to_s
      base = cur_line.lstrip.start_with?("end") ? prev_depth - 1 : prev_depth
      [base, 0].max * 2
    end
  LOG&.puts "[indent] line=#{line_index} newline=#{is_newline} lines=#{lines.inspect} => #{indent}"
  indent
end

# マルチライン入力の完了判定: open == close になった時点で完成
def balanced?(buf)
  opens  = buf.scan(OPEN).size
  closes = buf.scan(CLOSE).size
  opens == closes
end

puts "multiline mini-repl (empty line + Enter で評価)"
puts "例: def greet; 'hi'; end"
puts

loop do
  buf =
    Reline.readmultiline("bal> ", true) do |multiline_input|
      # ブロックが true を返したら入力完了。false なら継続。
      balanced?(multiline_input)
    end
  break if buf.nil?
  buf = buf.strip
  next if buf.empty?
  break if buf == "exit" || buf == "quit"

  opens  = buf.scan(OPEN).size
  closes = buf.scan(CLOSE).size
  puts "  [opens=#{opens}, closes=#{closes}, balanced=#{opens == closes}]"
  puts "  lines: #{buf.lines.size}"
end
puts "bye"
