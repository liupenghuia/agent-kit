#!/usr/bin/env ruby
# frozen_string_literal: true

# Generic static web presence check for product repos.
# Usage:
#   ruby scripts/check_static_web.rb [DIR] [--require id1,id2]
#
# Defaults DIR to frontend/web under PRODUCT_ROOT or cwd.

require "optparse"
require "pathname"

dir = nil
required_ids = []

parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/check_static_web.rb [DIR] [options]"
  opts.on("--require LIST", "Comma-separated HTML id attributes that must exist") do |v|
    required_ids = v.split(",").map(&:strip).reject(&:empty?)
  end
  opts.on("-h", "--help") { puts opts; exit 0 }
end
parser.parse!
dir = ARGV.shift

root = Pathname(ENV["PRODUCT_ROOT"] || Dir.pwd).expand_path
web = Pathname(dir || "frontend/web")
web = root.join(web) unless web.absolute?

required_files = %w[index.html app.js styles.css].map { |f| web.join(f) }
missing = required_files.reject(&:file?)
abort "missing web files under #{web}: #{missing.map { |p| p.basename }.join(', ')}" unless missing.empty?

html = required_files[0].read
abort "#{web}/index.html does not reference app.js" unless html.include?("app.js")
abort "#{web}/index.html does not reference styles.css" unless html.include?("styles.css")

required_ids.each do |id|
  abort "#{web}/index.html missing id=#{id.inspect}" unless html.include?(%(id="#{id}")) || html.include?(%(id='#{id}'))
end

puts "static web checks passed (#{web})"
