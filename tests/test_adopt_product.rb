#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "pathname"
require "tmpdir"
require "fileutils"
require "open3"
require "yaml"

KIT_ROOT = Pathname(__dir__).parent.expand_path

class AdoptProductTest < Minitest::Test
  def setup
    @dir = Pathname(Dir.mktmpdir) / "legacy-product"
    FileUtils.mkdir_p(@dir)
    %w[docs backend frontend tasks ideas issues scripts].each { |d| FileUtils.mkdir_p(@dir / d) }
    (@dir / "docs" / "requirements.md").write("# requirements\n")
    (@dir / "docs" / "architecture.md").write("# architecture\n")
    (@dir / "AGENTS.md").write("# existing agents\n")
    (@dir / "scripts" / "deliver.rb").write("#!/usr/bin/env ruby\nputs 'legacy'\n")
  end

  def teardown
    FileUtils.remove_entry(@dir.parent)
  end

  def test_adopt_preserves_truths_and_installs_wrappers
    out, err, status = Open3.capture3(
      "ruby",
      (KIT_ROOT / "scripts" / "adopt_product.rb").to_s,
      "--path", @dir.to_s,
      "--name", "recruitment",
      "--display-name", "寻职",
      "--preset", "api-web-miniprogram",
      "--mode", "link",
      "--kit-path", KIT_ROOT.to_s
    )
    assert status.success?, "#{out}\n#{err}"

    assert (@dir / "product.yaml").file?
    product = YAML.safe_load((@dir / "product.yaml").read, aliases: false)
    assert_equal "recruitment", product["name"]
    assert_equal true, product.dig("frontend_targets", "miniprogram")
    assert product.dig("delivery", "checks").any? { |c| c["id"] == "backend-health" }
    assert product.dig("delivery", "checks").any? { |c| c["type"] == "service_http" }

    # Truths preserved
    assert_equal "# requirements\n", (@dir / "docs" / "requirements.md").read
    assert_equal "# architecture\n", (@dir / "docs" / "architecture.md").read
    assert_equal "# existing agents\n", (@dir / "AGENTS.md").read

    # Legacy script backed up; new wrapper installed
    assert (@dir / "scripts" / "legacy" / "deliver.rb").file?
    wrapper = (@dir / "scripts" / "deliver.rb").read
    assert_match(/agent-delivery-kit|KIT_ROOT|product\.yaml/, wrapper)

    dout, derr, dstatus = Open3.capture3("ruby", (@dir / "scripts" / "doctor.rb").to_s)
    assert dstatus.success?, "#{dout}\n#{derr}"
    assert_match(/OK/, dout)

    vout, verr, vstatus = Open3.capture3("ruby", (@dir / "scripts" / "validate_workflow.rb").to_s)
    assert vstatus.success?, "#{vout}\n#{verr}"
  end
end
