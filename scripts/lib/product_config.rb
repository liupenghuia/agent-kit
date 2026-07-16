# frozen_string_literal: true

require "pathname"
require "yaml"
require_relative "kit_paths"

module AgentDelivery
  class ProductConfig
    DEFAULT_IMPLEMENTATION_SCOPES = %w[backend frontend mobile ios android].freeze
    DEFAULT_ALL_SCOPES = %w[product architecture backend frontend mobile ios android test release].freeze
    DEFAULT_OWNERS = [
      "Product Agent", "Architect Agent", "Backend Agent", "Frontend Agent", "Mobile Agent",
      "iOS Agent", "Android Agent", "Test Agent", "Orchestrator Agent"
    ].freeze

    attr_reader :root, :data, :path

    def self.load!(product_root = nil)
      root = Pathname(product_root || KitPaths.resolve_product_root!).expand_path
      path = root.join("product.yaml")
      abort "missing product.yaml: #{path}" unless path.file?
      data = YAML.safe_load(path.read, aliases: false)
      abort "product.yaml is empty: #{path}" unless data.is_a?(Hash)
      new(root, path, data).tap(&:validate!)
    end

    def initialize(root, path, data)
      @root = Pathname(root)
      @path = Pathname(path)
      @data = data
    end

    def name
      data["name"].to_s
    end

    def display_name
      data["display_name"] || name
    end

    def kit_version
      data["kit_version"].to_s
    end

    def scopes
      data["scopes"] || {}
    end

    def frontend_targets
      data["frontend_targets"] || {}
    end

    def frontend_target_keys
      frontend_targets.keys.map(&:to_s)
    end

    def implementation_scopes
      keys = scopes.keys.map(&:to_s)
      keys.empty? ? DEFAULT_IMPLEMENTATION_SCOPES : (DEFAULT_IMPLEMENTATION_SCOPES | keys)
    end

    def stacks
      data["stacks"] || {}
    end

    def truths
      data["truths"] || {}
    end

    def quality
      data["quality"] || {}
    end

    def delivery
      data["delivery"] || {}
    end

    def checks
      Array(delivery["checks"])
    end

    def human_gates
      Array(delivery["human_gates"])
    end

    def max_rounds
      Integer(delivery["max_rounds"] || 3)
    end

    def evidence_root
      delivery["evidence_root"] || "/tmp/agent-delivery/#{name}"
    end

    def command_timeout_sec
      Integer(delivery["command_timeout_sec"] || 180)
    end

    def owners
      DEFAULT_OWNERS
    end

    def when_true?(expression, task: nil)
      expr = expression.to_s.strip
      return true if expr.empty? || expr == "true"

      if expr.start_with?("scopes.")
        key = expr.delete_prefix("scopes.")
        return scope_enabled?(key, task: task)
      end

      if expr.start_with?("frontend_targets.")
        key = expr.delete_prefix("frontend_targets.")
        return target_enabled?(key, task: task)
      end

      abort "unsupported when expression: #{expression.inspect}"
    end

    def scope_enabled?(key, task: nil)
      if task && task["required_scopes"].is_a?(Hash) && task["required_scopes"].key?(key)
        return task["required_scopes"][key] == true
      end
      scopes[key] == true
    end

    def target_enabled?(key, task: nil)
      if task && task["frontend_targets"].is_a?(Hash) && task["frontend_targets"].key?(key)
        return task["frontend_targets"][key] == true
      end
      frontend_targets[key] == true
    end

    def applicable_checks(task: nil)
      checks.select do |check|
        when_true?(check["when"], task: task)
      end
    end

    def validate!
      errors = []
      errors << "product.yaml: missing name" if name.empty?
      errors << "product.yaml: scopes must be a mapping" unless scopes.is_a?(Hash)
      errors << "product.yaml: frontend_targets must be a mapping" unless frontend_targets.is_a?(Hash)
      errors << "product.yaml: delivery.checks must be a list" unless delivery["checks"].is_a?(Array)

      checks.each_with_index do |check, index|
        unless check.is_a?(Hash) && check["id"] && check["cmd"].is_a?(Array)
          errors << "product.yaml: checks[#{index}] requires id and cmd array"
        end
      end

      unless errors.empty?
        warn "product.yaml validation failed:"
        errors.each { |e| warn "- #{e}" }
        exit 1
      end
      self
    end
  end
end
