#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "pathname"
require "tmpdir"
require "fileutils"
require "open3"

KIT_ROOT = Pathname(__dir__).parent.expand_path

class InitProductTest < Minitest::Test
  def setup
    @dir = Pathname(Dir.mktmpdir) / "product"
  end

  def teardown
    FileUtils.remove_entry(@dir.parent)
  end

  def test_init_api_web_and_doctor
    out, err, status = Open3.capture3(
      "ruby",
      (KIT_ROOT / "scripts" / "init_product.rb").to_s,
      "--path", @dir.to_s,
      "--name", "demo",
      "--preset", "api-web",
      "--mode", "link",
      "--kit-path", KIT_ROOT.to_s
    )
    assert status.success?, "#{out}\n#{err}"
    assert (@dir / "product.yaml").file?
    assert (@dir / "AGENTS.md").file?
    assert (@dir / "scripts" / "doctor.rb").file?
    assert (@dir / "backend" / "src" / "app.js").file?
    assert (@dir / "frontend" / "web" / "app.js").file?

    dout, derr, dstatus = Open3.capture3("ruby", (@dir / "scripts" / "doctor.rb").to_s)
    assert dstatus.success?, "#{dout}\n#{derr}"
    assert_match(/OK/, dout)

    vout, verr, vstatus = Open3.capture3("ruby", (@dir / "scripts" / "validate_workflow.rb").to_s)
    assert vstatus.success?, "#{vout}\n#{verr}"
  end
end
