# frozen_string_literal: true
#
# Reline の API を使う最小 REPL。
# 固定語彙で Tab 補完し、履歴を持つ。
#
# 手元で対話的に動かす場合:
#   ruby work/irb-reline/07_reline_repl.rb
# テストハーネス(PTY で自動入力)経由:
#   ruby work/irb-reline/08_reline_repl_pty.rb

require "reline"

VOCAB = %w[help quit exit history show clear add multiply divide square].freeze

# 補完候補: 行全体から最後の単語を切り出して前方一致
Reline.completion_proc = ->(input) do
  VOCAB.select { |w| w.start_with?(input) }
end

# 履歴ファイル
HIST_FILE = File.join(__dir__, ".reline_history_tmp")
if File.exist?(HIST_FILE)
  File.readlines(HIST_FILE).each { |line| Reline::HISTORY << line.chomp }
end
at_exit { File.write(HIST_FILE, Reline::HISTORY.to_a.last(100).join("\n") + "\n") }

loop do
  line = Reline.readline("mini> ", true)  # 第2引数 true で履歴に追加
  break if line.nil?           # Ctrl-D (EOF)
  line = line.strip
  next if line.empty?

  case line
  when "quit", "exit"
    break
  when "history"
    Reline::HISTORY.to_a.each_with_index { |h, i| puts "#{(i + 1).to_s.rjust(3)}: #{h}" }
  when "clear"
    Reline::HISTORY.clear
    puts "(history cleared)"
  when /^(add|multiply|divide) (-?\d+(?:\.\d+)?) (-?\d+(?:\.\d+)?)$/
    a = $2.to_f
    b = $3.to_f
    result =
      case $1
      when "add"      then a + b
      when "multiply" then a * b
      when "divide"   then b.zero? ? "NaN" : a / b
      end
    puts "=> #{result}"
  when /^square (-?\d+(?:\.\d+)?)$/
    puts "=> #{$1.to_f ** 2}"
  when "help"
    puts "commands: #{VOCAB.join(", ")}"
    puts "  add A B, multiply A B, divide A B, square A"
  else
    puts "?? unknown: #{line.inspect}"
  end
end
puts "bye"
