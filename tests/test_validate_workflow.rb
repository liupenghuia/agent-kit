#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "pathname"
require "tmpdir"
require "fileutils"
require "yaml"
require "open3"

KIT_ROOT = Pathname(__dir__).parent.expand_path

class ValidateWorkflowTest < Minitest::Test
  def setup
    @dir = Pathname(Dir.mktmpdir)
    %w[ideas tasks issues docs scripts].each { |d| FileUtils.mkdir_p(@dir / d) }
    @dir.join("product.yaml").write({
      "name" => "demo",
      "kit_version" => "0.1.0",
      "scopes" => { "backend" => false, "frontend" => false, "mobile" => false, "ios" => false, "android" => false },
      "frontend_targets" => { "web" => false, "miniprogram" => false },
      "delivery" => { "checks" => [{ "id" => "workflow", "cmd" => %w[true] }] },
      "kit" => { "mode" => "link", "path" => KIT_ROOT.to_s },
    }.to_yaml)
    FileUtils.cp(KIT_ROOT / "templates" / "ideas" / "template.md", @dir / "ideas" / "template.md")
    FileUtils.cp(KIT_ROOT / "templates" / "tasks" / "template.md", @dir / "tasks" / "template.md")
    FileUtils.cp(KIT_ROOT / "templates" / "issues" / "template.md", @dir / "issues" / "template.md")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_empty_product_passes
    env = { "PRODUCT_ROOT" => @dir.to_s, "KIT_ROOT" => KIT_ROOT.to_s }
    out, err, status = Open3.capture3(env, "ruby", (KIT_ROOT / "scripts" / "validate_workflow.rb").to_s)
    assert status.success?, "#{out}\n#{err}"
    assert_match(/0 ideas, 0 tasks, 0 issues/, out)
  end
end
