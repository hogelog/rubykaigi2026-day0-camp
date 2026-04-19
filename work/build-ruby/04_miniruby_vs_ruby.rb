# frozen_string_literal: true

# miniruby と system ruby に同じプローブを流し、差分を出す。
# miniruby は「パーサ + 評価器 + 一部の built-in」しか持たないブートストラップ用 ruby。
# ここでは stdlib require / C 拡張 / encoding / rubygems / JIT 可視性 の 5 軸で可視化する。

probes = [
  ["version", -> { RUBY_DESCRIPTION }],
  ["defined? Gem", -> { defined?(Gem).inspect }],
  ["require 'json'", -> { require "json"; "ok (#{JSON::VERSION})" }],
  ["require 'openssl'", -> { require "openssl"; "ok" }],
  ["require 'bigdecimal'", -> { require "bigdecimal"; "ok" }],
  ["require 'fileutils'", -> { require "fileutils"; "ok" }],
  ["Encoding.list.size", -> { Encoding.list.size.to_s }],
  ["defined? RubyVM::YJIT", -> { defined?(RubyVM::YJIT).inspect }],
  ["defined? RubyVM::ZJIT", -> { defined?(RubyVM::ZJIT).inspect }],
  ["$LOAD_PATH.size", -> { $LOAD_PATH.size.to_s }],
]

probes.each do |label, thunk|
  result =
    begin
      thunk.call
    rescue Exception => e
      "[#{e.class}] #{e.message.lines.first&.strip}"
    end
  puts "#{label.ljust(28)} #{result}"
end
