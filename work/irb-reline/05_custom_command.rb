# frozen_string_literal: true
#
# IRB 拡張コマンド(新 API)を .irbrc で登録する実験。
# 実行: ruby work/irb-reline/05_custom_command.rb

require "tmpdir"

Dir.mktmpdir do |home|
  irbrc = File.join(home, ".irbrc")
  File.write(irbrc, <<~'RC')
    require "irb/command"
    require "irb/helper_method"

    # ---------- 1. Command: 副作用ベースの命令 ----------
    class CountMethods < IRB::Command::Base
      category "Camp"
      description "引数のクラスで定義されたメソッドを継承元ごとに集計する"
      help_message <<~HELP
        Usage: count_methods <expr>

        <expr> を評価して得た値の class について、ancestors のどこで
        定義されたかを集計してテーブル表示する。
      HELP

      def execute(arg)
        arg = arg.to_s.strip
        if arg.empty?
          puts "usage: count_methods <expr>"
          return
        end
        obj = @irb_context.workspace.binding.eval(arg)
        klass = obj.is_a?(Module) ? obj : obj.class
        grouped = klass.instance_methods(true).group_by do |m|
          klass.instance_method(m).owner
        end
        grouped.to_a.sort_by { |_, v| -v.size }.each do |owner, methods|
          puts "  %-30s %3d" % [owner, methods.size]
        end
        puts "  %-30s %3d" % ["(total)", klass.instance_methods(true).size]
      end
    end
    IRB::Command.register(:count_methods, CountMethods)

    # ---------- 2. HelperMethod: 戻り値を返すユーティリティ ----------
    class SelfClass < IRB::HelperMethod::Base
      description "現在のトップレベル self の class を返す"
      # HelperMethod は Singleton で context は渡されない。
      # 現在の IRB を知りたければ IRB.CurrentContext を自分で引く。
      def execute
        IRB.CurrentContext.workspace.binding.receiver.class
      end
    end
    IRB::HelperMethod.register(:self_class, SelfClass)
  RC

  script = <<~'IRB'
    count_methods Integer
    self_class
    self_class.ancestors.first(3)
    help count_methods
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
