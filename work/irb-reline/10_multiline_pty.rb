# frozen_string_literal: true
#
# 09_multiline.rb を PTY で駆動する。def ... end を数行に分けて入力し、
# auto_indent_proc がどう効くか、readmultiline のブロックが完成を
# 検知するタイミングを確認する。
#
# 実行: ruby work/irb-reline/10_multiline_pty.rb

require "pty"

script   = File.expand_path("09_multiline.rb", __dir__)
log_file = File.expand_path("indent.log", __dir__)
File.delete(log_file) if File.exist?(log_file)
env      = { "TERM" => "xterm-256color", "LINES" => "40", "COLUMNS" => "100",
             "INDENT_LOG" => log_file }

buf = +""
PTY.spawn(env, "ruby", "-W0", script) do |r, w, pid|
  inputs = [
    # 1 行完結: balanced? が最初から true -> 1 行で評価
    "1 + 1\r",
    # マルチライン: def ... end を 3 行で
    "def greet\r",           # open +1
    "\"hi\"\r",              # 継続
    "end\r",                 # close -1 -> balanced -> 評価
    # さらに複雑に: if + def の入れ子
    "if true\r",
    "def inner\r",
    "42\r",
    "end\r",
    "end\r",
    "exit\r",
  ]

  reader = Thread.new do
    begin
      while (c = r.readpartial(4096))
        buf << c
      end
    rescue Errno::EIO, EOFError
    end
  end

  # Reline の in_pasting? は「複数文字が一気に read できる = pasting」と
  # 判定して auto_indent_proc をスキップする。手打ち相当にするため、
  # 1 文字ずつ flush + sleep で送る。
  inputs.each do |s|
    s.each_char do |c|
      w.write(c)
      w.flush
      sleep 0.02
    end
    sleep 0.2
  end
  sleep 0.5
  begin
    Process.waitpid(pid)
  rescue Errno::ECHILD
  end
  reader.join(1)
end

clean = buf
  .gsub(/\e\[[0-9;?]*[A-Za-z]/, "")
  .gsub(/\e\][^\a]*\a/, "")
  .gsub(/\e[=>]/, "")
  .gsub(/\r/, "")

puts "---- escape-stripped (要点だけ) ----"
puts clean
puts
puts "---- indent proc log ----"
puts File.read(log_file) if File.exist?(log_file)
