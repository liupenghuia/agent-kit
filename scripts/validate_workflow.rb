#!/usr/bin/env ruby
# frozen_string_literal: true

# Validate idea/task/issue front matter for a product repository.
# Requires PRODUCT_ROOT (or cwd) to contain product.yaml.

require_relative "lib/kit_paths"
require_relative "lib/product_config"
require_relative "lib/workflow_validator"

product_root, = AgentDelivery::KitPaths.ensure_env!
product = AgentDelivery::ProductConfig.load!(product_root)
exit AgentDelivery::WorkflowValidator.new(product).run!
