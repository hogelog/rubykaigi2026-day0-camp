# frozen_string_literal: true
#
# IRB の式評価パイプラインを TracePoint で外から観察する。
# 実行: ruby work/irb-reline/11_pipeline_probe.rb
#
# 狙い: 1 つの入力が readmultiline -> parse_input -> Statement::{...} ->
# evaluate -> workspace.evaluate -> eval のどこを通るかを目で見る。

require "tmpdir"

trace_script = <<~'RUBY'
  require "irb"
  events = []
  tp = TracePoint.new(:call) do |t|
    next if t.path.include?("trace.rb") || t.path.include?("tempfile")
    next unless t.path =~ %r{/irb-1\.16\.0/lib/irb(\.rb|/context\.rb|/workspace\.rb|/statement\.rb)}
    events << [File.basename(t.path), t.method_id, t.lineno]
  end

  IRB.setup(nil)
  tp.enable
  begin
    IRB.start
  rescue SystemExit
  ensure
    tp.disable
    # 呼び出し順の骨格だけ出す(連続する同じメソッド呼びは 1 行に)
    last = nil
    events.each do |ev|
      next if ev == last
      last = ev
      puts "  %-15s %-30s :%d" % ev
    end
  end
RUBY

Dir.mktmpdir do |home|
  trace_rb = File.join(home, "trace.rb")
  File.write(trace_rb, trace_script)

  # .irbrc 不要。入力は単純化: 式 1 本 + コマンド 1 本 + exit
  input = <<~INPUT
    1 + 2
    help camp_hello
    exit
  INPUT

  out = IO.popen(
    { "HOME" => home, "TERM" => "dumb", "IRBRC" => "/dev/null" },
    ["ruby", trace_rb],
    "r+",
    err: [:child, :out],
  ) do |io|
    io.write(input)
    io.close_write
    io.read
  end
  puts out
end
