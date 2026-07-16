#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "pathname"
require "tmpdir"
require "fileutils"
require "yaml"

KIT_ROOT = Pathname(__dir__).parent.expand_path
$LOAD_PATH.unshift((KIT_ROOT / "scripts" / "lib").to_s)
require_relative "../scripts/lib/product_config"

class ProductConfigTest < Minitest::Test
  def setup
    @dir = Pathname(Dir.mktmpdir)
    @dir.join("product.yaml").write({
      "name" => "demo",
      "scopes" => { "backend" => true, "frontend" => true },
      "frontend_targets" => { "web" => true, "miniprogram" => false },
      "delivery" => {
        "checks" => [
          { "id" => "workflow", "cmd" => %w[ruby scripts/validate_workflow.rb] },
          { "id" => "backend-test", "when" => "scopes.backend", "cmd" => %w[npm test] },
          { "id" => "web-syntax", "when" => "frontend_targets.web", "cmd" => %w[node --check frontend/web/app.js] },
          { "id" => "mp", "when" => "frontend_targets.miniprogram", "cmd" => %w[true] },
        ],
      },
    }.to_yaml)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_loads_and_filters_checks
    product = AgentDelivery::ProductConfig.load!(@dir)
    assert_equal "demo", product.name
    ids = product.applicable_checks.map { |c| c["id"] }
    assert_includes ids, "workflow"
    assert_includes ids, "backend-test"
    assert_includes ids, "web-syntax"
    refute_includes ids, "mp"
  end

  def test_task_overrides_when
    product = AgentDelivery::ProductConfig.load!(@dir)
    task = {
      "required_scopes" => { "backend" => false },
      "frontend_targets" => { "web" => false, "miniprogram" => true },
    }
    ids = product.applicable_checks(task: task).map { |c| c["id"] }
    refute_includes ids, "backend-test"
    refute_includes ids, "web-syntax"
    assert_includes ids, "mp"
  end
end
