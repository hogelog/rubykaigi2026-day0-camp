# frozen_string_literal: true
#
# 自作 Command / HelperMethod が `help` のテーブルに載ることを確認。
# 実行: ruby work/irb-reline/06_help_integration.rb

require "tmpdir"

Dir.mktmpdir do |home|
  irbrc = File.join(home, ".irbrc")
  File.write(irbrc, <<~'RC')
    require "irb/command"
    require "irb/helper_method"

    class CampHello < IRB::Command::Base
      category "Camp"
      description "合宿挨拶"
      def execute(arg) = puts "hi from camp!"
    end
    IRB::Command.register(:camp_hello, CampHello)

    class CampSize < IRB::HelperMethod::Base
      description "合宿 helper: 42 を返すだけ"
      def execute = 42
    end
    IRB::HelperMethod.register(:camp_size, CampSize)
  RC

  out = IO.popen(
    { "HOME" => home, "IRBRC" => irbrc, "TERM" => "dumb" },
    ["irb", "--nomultiline", "--nocolorize"],
    "r+",
    err: [:child, :out],
  ) do |io|
    io.write("help\nexit\n")
    io.close_write
    io.read
  end

  # "Camp" / "Helper methods" セクションだけ抜き出して表示
  in_section = false
  out.each_line do |line|
    if line =~ /^(Camp|Helper methods|Aliases)\b/
      in_section = true
      puts line
    elsif in_section
      if line.strip.empty?
        in_section = false
        puts
      else
        puts line
      end
    end
  end
end
