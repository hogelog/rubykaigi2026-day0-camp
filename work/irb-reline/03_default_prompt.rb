# frozen_string_literal: true
#
# .irbrc で PROMPT_MODE を設定しなかった時の規定値を確認。
# IRB.conf 単独 setup() では :NULL だったが、実 irb 起動時はどうなるか。

require "tmpdir"

Dir.mktmpdir do |home|
  irbrc = File.join(home, ".irbrc")
  # PROMPT_MODE を触らない、カラーだけ切る
  File.write(irbrc, "IRB.conf[:USE_COLORIZE] = false\n")

  script = <<~'IRB'
    IRB.conf[:PROMPT_MODE]
    IRB.conf.fetch(:__dummy__, :not_set)
    exit
  IRB

  out = IO.popen(
    { "HOME" => home, "IRBRC" => irbrc, "TERM" => "dumb" },
    ["irb", "--nomultiline", "--nocolorize"],
    "r+",
    err: [:child, :out],
  ) do |io|
    io.write(script)
    io.close_write
    io.read
  end
  puts out
end
