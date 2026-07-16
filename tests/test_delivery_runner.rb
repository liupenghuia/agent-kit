#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "pathname"
require "tmpdir"
require "fileutils"
require "open3"
require "yaml"

KIT_ROOT = Pathname(__dir__).parent.expand_path

class DeliveryRunnerTest < Minitest::Test
  def setup
    @dir = Pathname(Dir.mktmpdir)
    %w[ideas tasks issues docs scripts backend/src].each { |d| FileUtils.mkdir_p(@dir / d) }

    (@dir / "backend" / "src" / "app.js").write(<<~JS)
      "use strict";
      function createApp() {
        return {
          handle(req, res) {
            if (req.url === "/health") {
              res.statusCode = 200;
              res.setHeader("content-type", "application/json");
              res.end(JSON.stringify({ status: "ok" }));
              return;
            }
            res.statusCode = 404;
            res.end("not found");
          },
        };
      }
      module.exports = { createApp };
    JS
    (@dir / "backend" / "src" / "server.js").write(<<~JS)
      "use strict";
      const http = require("http");
      const { createApp } = require("./app");
      const port = Number(process.env.PORT || 3000);
      const app = createApp();
      http.createServer((req, res) => app.handle(req, res)).listen(port, "127.0.0.1");
    JS
    (@dir / "backend" / "src" / "extra.js").write(%("use strict";\nmodule.exports = { ok: true };\n))

    evidence = @dir / "evidence"
    (@dir / "product.yaml").write({
      "name" => "delivery-demo",
      "kit_version" => "0.2.0",
      "scopes" => {
        "backend" => true, "frontend" => false, "mobile" => false, "ios" => false, "android" => false
      },
      "frontend_targets" => { "web" => false, "miniprogram" => false },
      "delivery" => {
        "max_rounds" => 1,
        "evidence_root" => evidence.to_s,
        "command_timeout_sec" => 30,
        "checks" => [
          {
            "id" => "backend-syntax",
            "when" => "scopes.backend",
            "cwd" => "backend",
            "cmd" => %w[node --check],
            "glob" => "src/**/*.js",
          },
          {
            "id" => "backend-health",
            "when" => "scopes.backend",
            "type" => "service_http",
            "cwd" => "backend",
            "start" => %w[node src/server.js],
            "env" => { "PORT" => "{{port}}", "NODE_ENV" => "test" },
            "health_url" => "http://127.0.0.1:{{port}}/health",
            "ready_timeout_sec" => 10,
          },
        ],
      },
      "kit" => { "mode" => "link", "path" => KIT_ROOT.to_s },
    }.to_yaml)

    (@dir / "tasks" / "sample.md").write(<<~MD)
      ---
      id: TASK-20260716-001
      title: sample
      status: In Progress
      priority: P2
      owner: Backend Agent
      created: 2026-07-16
      updated: 2026-07-16
      source_idea:
      depends_on: []
      linked_issues: []
      required_scopes:
        backend: true
        frontend: false
        mobile: false
        ios: false
        android: false
      frontend_targets:
        miniprogram: false
        web: false
      frontend_target_status:
        miniprogram: N/A
        web: N/A
      scope_status:
        product: Done
        architecture: Done
        backend: In Progress
        frontend: N/A
        mobile: N/A
        ios: N/A
        android: N/A
        test: Pending
        release: N/A
      release_required: false
      ---

      # sample
    MD

    wrapper = <<~RUBY
      #!/usr/bin/env ruby
      require "pathname"
      require "yaml"
      PRODUCT_ROOT = Pathname(#{@dir.to_s.inspect}).realpath
      ENV["PRODUCT_ROOT"] = PRODUCT_ROOT.to_s
      ENV["KIT_ROOT"] = #{KIT_ROOT.to_s.inspect}
      load Pathname(ENV["KIT_ROOT"]).join("scripts", "deliver.rb").to_s
    RUBY
    (@dir / "scripts" / "deliver.rb").write(wrapper)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_glob_and_health_pass
    out, err, status = Open3.capture3(
      { "PRODUCT_ROOT" => @dir.to_s, "KIT_ROOT" => KIT_ROOT.to_s },
      "ruby", (@dir / "scripts" / "deliver.rb").to_s, "sample"
    )
    assert status.success?, "#{out}\n#{err}"
    assert_match(/passed|report:/i, out)

    reports = Dir[@dir.join("evidence", "TASK-20260716-001", "*", "report.md")]
    assert !reports.empty?, "expected delivery report under evidence"
    body = File.read(reports.max)
    assert_match(/Passed/, body)
    assert_match(/backend-syntax/, body)
    assert_match(/backend-health/, body)
  end
end
