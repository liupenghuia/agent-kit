# frozen_string_literal: true

require "pathname"
require "yaml"

module AgentDelivery
  module KitPaths
    module_function

    def kit_root
      Pathname(ENV.fetch("KIT_ROOT") { Pathname(__dir__).join("../..").expand_path }).expand_path
    end

    def product_root
      Pathname(ENV.fetch("PRODUCT_ROOT") { Dir.pwd }).expand_path
    end

    def resolve_product_root!(explicit = nil)
      root = Pathname(explicit || ENV["PRODUCT_ROOT"] || Dir.pwd).expand_path
      config = root.join("product.yaml")
      return root if config.file?

      # When invoked from kit scripts without PRODUCT_ROOT, allow cwd product.yaml.
      abort "missing product.yaml under PRODUCT_ROOT=#{root} (set PRODUCT_ROOT or run from a product repo)"
    end

    def resolve_kit_root_from_product(product_root)
      product_root = Pathname(product_root).expand_path
      config_path = product_root.join("product.yaml")
      abort "missing product.yaml: #{config_path}" unless config_path.file?

      product = YAML.safe_load(config_path.read, aliases: false) || {}
      kit_meta = product["kit"] || {}
      path = kit_meta["path"]

      if path.nil? || path.to_s.empty?
        # Default: kit scripts themselves
        return kit_root
      end

      if path.to_s == "vendored"
        return product_root.join("vendor/agent-delivery-kit").expand_path
      end

      candidate = Pathname(path)
      candidate = product_root.join(candidate) unless candidate.absolute?
      candidate = candidate.expand_path
      abort "kit path not found: #{candidate}" unless candidate.directory?
      candidate
    end

    def ensure_env!(product_root: nil, kit_root: nil)
      pr = Pathname(product_root || resolve_product_root!).expand_path
      kr = Pathname(kit_root || resolve_kit_root_from_product(pr)).expand_path
      ENV["PRODUCT_ROOT"] = pr.to_s
      ENV["KIT_ROOT"] = kr.to_s
      [pr, kr]
    end
  end
end
