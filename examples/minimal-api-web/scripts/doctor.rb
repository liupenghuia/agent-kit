#!/usr/bin/env ruby
# frozen_string_literal: true
# Thin wrapper — implementation lives in agent-delivery-kit.

require "pathname"
require "yaml"

PRODUCT_ROOT = Pathname(__dir__).parent.realpath
ENV["PRODUCT_ROOT"] = PRODUCT_ROOT.to_s

config_path = PRODUCT_ROOT.join("product.yaml")
abort "missing product.yaml" unless config_path.file?
product = YAML.safe_load(config_path.read, aliases: false) || {}
kit = product.dig("kit", "path")
kit_root =
  if kit.nil? || kit.to_s.empty?
    abort "product.yaml kit.path is required"
  elsif kit.to_s == "vendored"
    PRODUCT_ROOT.join("vendor/agent-delivery-kit")
  else
    path = Pathname(kit)
    path.absolute? ? path : PRODUCT_ROOT.join(path)
  end
kit_root = kit_root.expand_path
kit_root = kit_root.realpath if kit_root.exist?
abort "kit not found: #{kit_root}" unless kit_root.directory?
ENV["KIT_ROOT"] = kit_root.to_s

load kit_root.join("scripts", "doctor.rb").to_s
