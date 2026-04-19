# frozen_string_literal: true
#
# ダミー .irbrc を置いて irb をバッチ実行し、何が起きたかを観察する。
# 実行: ruby work/irb-reline/02_irbrc.rb

require "tmpdir"
require "fileutils"

Dir.mktmpdir do |home|
  irbrc = File.join(home, ".irbrc")
  File.write(irbrc, <<~'RC')
    # プロンプトを短く差し替える
    IRB.conf[:PROMPT][:CAMP] = {
      PROMPT_I: "camp> ",
      PROMPT_S: "camp* ",
      PROMPT_C: "camp... ",
      RETURN:   "=> %s\n",
    }
    IRB.conf[:PROMPT_MODE] = :CAMP

    # 自分用エイリアス: `m` で public_methods を --grep で絞る
    IRB.conf[:COMMAND_ALIASES][:m] = :show_source

    # カラーを切る (スクリーンショットや diff しやすい)
    IRB.conf[:USE_COLORIZE] = false

    # 小さなヘルパを main に定義
    def hi(name = "camp") = "hi, #{name}!"
    puts "[.irbrc] loaded: $0=#{$0}, PROMPT_MODE=#{IRB.conf[:PROMPT_MODE]}"
  RC

  script = <<~'IRB'
    hi
    hi("ruby")
    IRB.conf[:PROMPT_MODE]
    IRB.conf[:USE_COLORIZE]
    IRB.conf[:COMMAND_ALIASES][:m]
    exit
  IRB

  # IRBRC 環境変数で .irbrc の場所を指定する。-f を付けると rc 読み込みが
  # 完全にスキップされるので付けない。HOME を tmpdir にして既存の .irbrc と
  # 混ざらないようにする。
  out = IO.popen(
    { "HOME" => home, "IRBRC" => irbrc, "TERM" => "dumb", "XDG_CONFIG_HOME" => home },
    ["irb", "--nomultiline", "--nocolorize"],
    "r+",
    err: [:child, :out],
  ) do |io|
    io.write(script)
    io.close_write
    io.read
  end

  puts "---- irb stdout ----"
  puts out
  puts "---- /irb stdout ---"
end
