# frozen_string_literal: true
#
# 07_reline_repl.rb を PTY 経由で駆動し、Reline の実挙動を観察する。
# 非対話環境でも疑似 TTY を用意することで、Reline のエスケープシーケンス
# (カーソル移動・ベル・履歴検索) を含む完全な動作を再現できる。
#
# 実行: ruby work/irb-reline/08_reline_repl_pty.rb

require "pty"
require "io/console"

# 先に履歴ファイルを掃除
hist = File.join(__dir__, ".reline_history_tmp")
File.delete(hist) if File.exist?(hist)

script = File.expand_path("07_reline_repl.rb", __dir__)

# 端末サイズを明示して子プロセスに引き継ぐ
env = { "TERM" => "xterm-256color", "LINES" => "40", "COLUMNS" => "100" }
out_buf = +""
PTY.spawn(env, "ruby", script) do |r, w, pid|
  # 送り込むキーストローク
  inputs = [
    "help\r",
    "add 3 4\r",
    "multiply 5 6\r",
    "squ\t",                # Tab で squ -> square を補完
    " 7\r",
    "history\r",
    "quit\r",
  ]

  reader = Thread.new do
    begin
      while (chunk = r.readpartial(4096))
        out_buf << chunk
      end
    rescue Errno::EIO, EOFError
      # PTY 閉じ
    end
  end

  inputs.each do |keys|
    sleep 0.15
    w.write(keys)
    w.flush
  end
  sleep 0.3

  begin
    Process.waitpid(pid, Process::WNOHANG) || Process.waitpid(pid)
  rescue Errno::ECHILD
  end
  reader.join(1)
end

puts "---- raw PTY output (#{out_buf.bytesize} bytes) ----"
puts out_buf
puts "---- /raw ----"
puts
puts "---- escape-stripped ----"
# 代表的な ANSI エスケープシーケンスを落として要点だけ見る
clean = out_buf
  .gsub(/\e\[[0-9;?]*[A-Za-z]/, "")
  .gsub(/\e\][^\a]*\a/, "")
  .gsub(/\e[=>]/, "")
  .gsub(/\r/, "")
puts clean
