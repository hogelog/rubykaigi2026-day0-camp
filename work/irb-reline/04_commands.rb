# frozen_string_literal: true
#
# IRB の組み込みコマンドをカテゴリ別に並べる。
# 実行: ruby work/irb-reline/04_commands.rb

require "irb"
require "irb/default_commands"

commands = IRB::Command.commands
puts "全コマンド数: #{commands.size}"
puts

# カテゴリで groupby
by_category = Hash.new { |h, k| h[k] = [] }
commands.each do |name, (klass, aliases)|
  alias_names = aliases.map { |a, _policy| a }
  by_category[klass.category] << {
    name:        name,
    aliases:     alias_names,
    description: klass.description,
    klass:       klass,
  }
end

by_category.sort_by { |c, _| c.to_s }.each do |category, items|
  puts "## #{category} (#{items.size})"
  items.sort_by { |i| i[:name].to_s }.each do |i|
    alias_s = i[:aliases].empty? ? "" : "  [aliases: #{i[:aliases].join(", ")}]"
    puts "  #{i[:name].to_s.ljust(32)} #{i[:description]}#{alias_s}"
  end
  puts
end

puts "## ExtendCommand は Command のエイリアス?"
puts "  IRB::ExtendCommand.equal?(IRB::Command) #=> #{IRB::ExtendCommand.equal?(IRB::Command)}"
