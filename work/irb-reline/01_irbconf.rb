# frozen_string_literal: true
#
# IRB.conf の中身を覗く。実行:
#   ruby work/irb-reline/01_irbconf.rb
#
# `require "irb"` だけでは IRB.conf はほぼ空。IRB.setup を明示的に呼ぶと
# IRB.init_config / IRB.load_modules が走り、デフォルト設定が入る。
# (通常は `irb` コマンド起動時に IRB.start 経由で setup される)

require "irb"

puts "IRB version: #{IRB::VERSION}"
puts

puts "=== before IRB.setup ==="
puts "IRB.conf.size = #{IRB.conf.size}"
puts "keys: #{IRB.conf.keys.inspect}"
puts

IRB.setup(nil)

puts "=== after IRB.setup(nil) ==="
puts "IRB.conf.size = #{IRB.conf.size}"
puts "keys (sorted):"
IRB.conf.keys.sort.each { |k| puts "  #{k.inspect}" }
puts

puts "=== 主要キーの値 ==="
%i[PROMPT PROMPT_MODE AUTO_INDENT USE_AUTOCOMPLETE USE_COLORIZE USE_PAGER
   HISTORY_FILE SAVE_HISTORY ECHO ECHO_ON_ASSIGNMENT COMMAND_ALIASES
   IRB_LIB_PATH LC_MESSAGES].each do |k|
  v = IRB.conf[k]
  case v
  when Hash
    puts "IRB.conf[#{k.inspect}] = Hash with #{v.size} entries"
    v.first(3).each { |kk, vv| puts "  #{kk.inspect} => #{vv.inspect[0, 80]}" }
    puts "  ..." if v.size > 3
  else
    puts "IRB.conf[#{k.inspect}] = #{v.inspect[0, 120]}"
  end
end
puts

puts "=== PROMPT の :DEFAULT ==="
p IRB.conf[:PROMPT][:DEFAULT]
puts
puts "=== COMMAND_ALIASES (エイリアス → 実コマンド) ==="
IRB.conf[:COMMAND_ALIASES].each { |a, real| puts "  #{a.inspect.ljust(10)} -> #{real.inspect}" }
