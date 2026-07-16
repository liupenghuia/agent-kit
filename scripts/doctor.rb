#!/usr/bin/env ruby
# frozen_string_literal: true

# Diagnose product + kit wiring.
# Usage: ruby scripts/doctor.rb

require "pathname"
require "rbconfig"
require_relative "lib/kit_paths"
require_relative "lib/product_config"

errors = []
warnings = []

product_root = begin
  AgentDelivery::KitPaths.resolve_product_root!
rescue SystemExit
  raise
rescue StandardError => e
  abort "doctor failed: #{e.message}"
end

kit_root = begin
  AgentDelivery::KitPaths.resolve_kit_root_from_product(product_root)
rescue StandardError => e
  abort "doctor failed: #{e.message}"
end

ENV["PRODUCT_ROOT"] = product_root.to_s
ENV["KIT_ROOT"] = kit_root.to_s

ruby_version = RUBY_VERSION
if Gem::Version.new(ruby_version) < Gem::Version.new("2.6.0")
  errors << "Ruby 2.6+ required (found #{ruby_version})"
elsif Gem::Version.new(ruby_version) < Gem::Version.new("3.0.0")
  warnings << "Ruby 3+ recommended (found #{ruby_version}); kit is tested against 2.6+ for host macOS compatibility"
end

kit_version_file = kit_root.join("VERSION")
errors << "kit VERSION missing: #{kit_version_file}" unless kit_version_file.file?

product = begin
  AgentDelivery::ProductConfig.load!(product_root)
rescue SystemExit
  exit 1
end

if kit_version_file.file? && !product.kit_version.empty?
  kit_ver = kit_version_file.read.strip
  prod_major = product.kit_version.split(".").first
  kit_major = kit_ver.split(".").first
  if prod_major != kit_major
    errors << "kit major mismatch: product.yaml kit_version=#{product.kit_version} kit VERSION=#{kit_ver}"
  elsif product.kit_version != kit_ver
    warnings << "kit patch/minor differs: product.yaml=#{product.kit_version} kit=#{kit_ver}"
  end
end

%w[ideas tasks issues docs scripts].each do |dir|
  errors << "missing directory: #{dir}/" unless product_root.join(dir).directory?
end

product.truths.each do |key, rel|
  path = product_root.join(rel.to_s)
  warnings << "truths.#{key} missing: #{rel}" unless path.file?
end

product.stacks.each do |role, stack_id|
  stack_path = kit_root.join("stacks", stack_id.to_s)
  errors << "stack not found in kit: #{stack_id}" unless stack_path.directory?
end

product.checks.each do |check|
  cmd = Array(check["cmd"])
  next if cmd.empty?
  if cmd[0] == "ruby" && cmd[1].to_s.start_with?("scripts/")
    script = product_root.join(cmd[1])
    warnings << "check #{check['id']}: script missing #{cmd[1]}" unless script.file?
  end
end

%w[AGENTS.md product.yaml].each do |name|
  errors << "missing #{name}" unless product_root.join(name).file?
end

puts "agent-delivery-kit doctor"
puts "  product_root: #{product_root}"
puts "  kit_root:     #{kit_root}"
puts "  product:      #{product.name} (#{product.display_name})"
puts "  kit_version:  #{product.kit_version}"
puts "  ruby:         #{ruby_version} (#{RbConfig::CONFIG['ruby_install_name']})"
puts "  scopes:       #{product.scopes.inspect}"
puts "  targets:      #{product.frontend_targets.inspect}"
puts "  checks:       #{product.checks.map { |c| c['id'] }.join(', ')}"

warnings.each { |w| warn "WARN: #{w}" }
if errors.empty?
  puts "OK"
  exit 0
end

warn "FAIL:"
errors.each { |e| warn "- #{e}" }
exit 1
