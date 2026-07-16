#!/usr/bin/env ruby
# frozen_string_literal: true

# Adopt agent-delivery-kit into an EXISTING product repository without clobbering
# business truths (requirements, architecture, openapi, database, tasks, ideas).
#
# Usage:
#   ruby scripts/adopt_product.rb \
#     --path ~/work/agents-project \
#     --name recruitment \
#     --display-name "寻职" \
#     --preset api-web-miniprogram \
#     --mode link \
#     --kit-path "$(pwd)"

require "fileutils"
require "optparse"
require "pathname"
require "yaml"

KIT_ROOT = Pathname(__dir__).parent.expand_path

PRESETS = {
  "api-web" => {
    scopes: { backend: true, frontend: true, mobile: false, ios: false, android: false },
    frontend_targets: { web: true, miniprogram: false },
    stacks: { backend: "node-api", web: "static-admin-web" },
  },
  "api-miniprogram" => {
    scopes: { backend: true, frontend: true, mobile: false, ios: false, android: false },
    frontend_targets: { web: false, miniprogram: true },
    stacks: { backend: "node-api", miniprogram: "wechat-miniprogram" },
  },
  "api-web-miniprogram" => {
    scopes: { backend: true, frontend: true, mobile: false, ios: false, android: false },
    frontend_targets: { web: true, miniprogram: true },
    stacks: {
      backend: "node-api",
      web: "static-admin-web",
      miniprogram: "wechat-miniprogram",
    },
  },
  "docs-only" => {
    scopes: { backend: false, frontend: false, mobile: false, ios: false, android: false },
    frontend_targets: { web: false, miniprogram: false },
    stacks: {},
  },
}.freeze

PROCESS_DOCS = %w[
  delivery-workflow.md
  code-quality-prerequisites.md
  iterative-implementation-guidelines.md
  product-discovery.md
  product-request-template.md
  testing.md
  client-architecture.md
].freeze

options = {
  path: nil,
  name: nil,
  display_name: nil,
  mode: "link",
  kit_path: KIT_ROOT.to_s,
  preset: "api-web-miniprogram",
  backup_scripts: true,
  write_product_yaml: :if_missing,
  write_agents: :if_missing,
  install_adapters: true,
  dry_run: false,
  evidence_root: nil,
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/adopt_product.rb --path DIR --name SLUG [options]"
  opts.on("--path DIR", "Existing product repository root") { |v| options[:path] = v }
  opts.on("--name SLUG", "Product slug for product.yaml") { |v| options[:name] = v }
  opts.on("--display-name NAME", "Human title") { |v| options[:display_name] = v }
  opts.on("--mode MODE", "link or copy (default: link)") { |v| options[:mode] = v }
  opts.on("--kit-path DIR", "Path to agent-delivery-kit") { |v| options[:kit_path] = v }
  opts.on("--preset NAME", "api-web | api-miniprogram | api-web-miniprogram | docs-only") { |v| options[:preset] = v }
  opts.on("--evidence-root DIR", "delivery.evidence_root override") { |v| options[:evidence_root] = v }
  opts.on("--no-backup-scripts", "Do not move existing scripts to scripts/legacy/") { options[:backup_scripts] = false }
  opts.on("--force-product-yaml", "Overwrite product.yaml") { options[:write_product_yaml] = :force }
  opts.on("--force-agents", "Overwrite root AGENTS.md from kit template") { options[:write_agents] = :force }
  opts.on("--skip-adapters", "Do not install Claude/Cursor/Grok adapters") { options[:install_adapters] = false }
  opts.on("--dry-run", "Print actions only") { options[:dry_run] = true }
  opts.on("-h", "--help") { puts opts; exit 0 }
end
parser.parse!

abort parser.to_s if options[:path].to_s.empty? || options[:name].to_s.empty?
abort "unknown preset: #{options[:preset]}" unless PRESETS.key?(options[:preset])
abort "mode must be link or copy" unless %w[link copy].include?(options[:mode])

product_root = Pathname(options[:path]).expand_path
kit_root = Pathname(options[:kit_path]).expand_path
abort "product path not found: #{product_root}" unless product_root.directory?
abort "kit not found: #{kit_root}" unless kit_root.join("VERSION").file? || kit_root.join("core").directory?

preset = PRESETS[options[:preset]]
kit_version = begin
  (kit_root / "VERSION").read.strip
rescue StandardError
  "0.0.0-dev"
end
display = options[:display_name] || options[:name]
kit_path_value =
  if options[:mode] == "copy"
    "vendored"
  else
    kit_root.expand_path.to_s
  end

def log(msg, dry_run:)
  prefix = dry_run ? "[dry-run] " : ""
  puts "#{prefix}#{msg}"
end

def write_file(path, content, dry_run:)
  log("write #{path}", dry_run: dry_run)
  return if dry_run
  FileUtils.mkdir_p(path.dirname)
  path.write(content)
end

def copy_if_missing(src, dest, dry_run:, force: false)
  if dest.exist? && !force
    log("skip existing #{dest}", dry_run: dry_run)
    return
  end
  log("copy #{src} -> #{dest}", dry_run: dry_run)
  return if dry_run
  FileUtils.mkdir_p(dest.dirname)
  FileUtils.cp(src, dest)
end

def render(template, vars)
  out = template.dup
  vars.each { |k, v| out.gsub!("{{#{k}}}", v.to_s) }
  out
end

# --- directories ---
%w[ideas tasks issues docs scripts].each do |dir|
  target = product_root / dir
  next if target.directory?
  log("mkdir #{target}", dry_run: options[:dry_run])
  FileUtils.mkdir_p(target) unless options[:dry_run]
end

# --- process docs (never overwrite) ---
PROCESS_DOCS.each do |name|
  src = kit_root / "docs" / name
  next unless src.file?
  copy_if_missing(src, product_root / "docs" / name, dry_run: options[:dry_run])
end

# --- templates if missing ---
[
  ["templates/ideas/template.md", "ideas/template.md"],
  ["templates/tasks/template.md", "tasks/template.md"],
  ["templates/issues/template.md", "issues/template.md"],
  ["core/COMMANDS.md", "COMMANDS.md"],
].each do |from, to|
  src = kit_root / from
  next unless src.file?
  copy_if_missing(src, product_root / to, dry_run: options[:dry_run])
end

# --- merge stack checks ---
checks = [{ "id" => "workflow", "cmd" => %w[ruby scripts/validate_workflow.rb] }]
preset[:stacks].each_value do |stack_id|
  checks_file = kit_root / "stacks" / stack_id / "checks.yaml"
  next unless checks_file.file?
  fragment = YAML.safe_load(checks_file.read, aliases: false) || {}
  Array(fragment["checks"]).each { |c| checks << c }
end

# Prefer product-local static check if already present (main business).
if (product_root / "scripts" / "check_web.rb").file?
  checks = checks.map do |c|
    next c unless c["id"] == "web-static"
    c.merge("cmd" => %w[ruby scripts/check_web.rb])
  end
end

evidence = options[:evidence_root] || "/tmp/agent-delivery/#{options[:name]}"

product_yaml = {
  "kit_version" => kit_version,
  "name" => options[:name],
  "display_name" => display,
  "locales" => ["zh"],
  "decision_owner" => "User",
  "scopes" => preset[:scopes].transform_keys(&:to_s),
  "frontend_targets" => preset[:frontend_targets].transform_keys(&:to_s),
  "stacks" => preset[:stacks].transform_keys(&:to_s),
  "truths" => {
    "requirements" => "docs/requirements.md",
    "architecture" => "docs/architecture.md",
    "openapi" => "docs/openapi.yaml",
    "database" => "docs/database.md",
    "discovery" => "docs/product-discovery.md",
    "client_architecture" => "docs/client-architecture.md",
    "testing" => "docs/testing.md",
    "quality" => "docs/code-quality-prerequisites.md",
    "workflow" => "docs/delivery-workflow.md",
  },
  "quality" => {
    "mode" => "code-first",
    "require_client_precheck" => true,
    "commit_coauthor" => true,
  },
  "delivery" => {
    "max_rounds" => 3,
    "evidence_root" => evidence,
    "command_timeout_sec" => 180,
    "checks" => checks,
    "human_gates" => [
      {
        "id" => "wechat-devtools",
        "description" => "WeChat DevTools / real-device authorization remains a human gate",
        "when" => "frontend_targets.miniprogram",
      },
      {
        "id" => "production-deploy",
        "description" => "Production deploy requires explicit approval",
      },
    ],
  },
  "kit" => {
    "mode" => options[:mode],
    "path" => kit_path_value,
  },
  "owners" => {
    "product" => "Product Agent",
    "architect" => "Architect Agent",
    "backend" => "Backend Agent",
    "frontend" => "Frontend Agent",
    "mobile" => "Mobile Agent",
    "ios" => "iOS Agent",
    "android" => "Android Agent",
    "test" => "Test Agent",
    "orchestrator" => "Orchestrator Agent",
  },
}

product_yaml_path = product_root / "product.yaml"
if product_yaml_path.file? && options[:write_product_yaml] != :force
  log("keep existing product.yaml (use --force-product-yaml to replace)", dry_run: options[:dry_run])
  # Still refresh kit.path when missing or empty? Safer: only if kit section absent.
  unless options[:dry_run]
    existing = YAML.safe_load(product_yaml_path.read, aliases: false) || {}
    if existing.dig("kit", "path").to_s.empty?
      existing["kit"] = { "mode" => options[:mode], "path" => kit_path_value }
      existing["kit_version"] ||= kit_version
      product_yaml_path.write(
        "# Updated by agent-delivery-kit adopt_product.rb\n" + existing.to_yaml
      )
      log("patched kit.path into product.yaml", dry_run: false)
    end
  end
else
  write_file(
    product_yaml_path,
    "# Generated by agent-delivery-kit adopt_product.rb\n" + product_yaml.to_yaml,
    dry_run: options[:dry_run]
  )
end

# --- AGENTS.md ---
agents_dest = product_root / "AGENTS.md"
agents_tpl = kit_root / "core" / "AGENTS.root.md"
if agents_tpl.file? && (options[:write_agents] == :force || !agents_dest.exist?)
  content = render(agents_tpl.read, {
    "PRODUCT_NAME" => display,
    "PRODUCT_SLUG" => options[:name],
    "KIT_VERSION" => kit_version,
    "KIT_PATH" => options[:mode] == "link" ? kit_path_value : "./vendor/agent-delivery-kit",
    "QUALITY_MODE" => "code-first",
  })
  write_file(agents_dest, content, dry_run: options[:dry_run])
else
  log("keep existing AGENTS.md (use --force-agents to replace)", dry_run: options[:dry_run])
end

# --- script wrappers ---
wrapper_template = <<~'RUBY'
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

  load kit_root.join("scripts", "__SCRIPT__").to_s
RUBY

%w[validate_workflow.rb deliver.rb doctor.rb].each do |script|
  dest = product_root / "scripts" / script
  if dest.file? && options[:backup_scripts]
    legacy = product_root / "scripts" / "legacy" / script
    log("backup #{dest} -> #{legacy}", dry_run: options[:dry_run])
    unless options[:dry_run]
      FileUtils.mkdir_p(legacy.dirname)
      FileUtils.mv(dest, legacy) unless legacy.exist?
      FileUtils.rm_f(dest) if dest.exist? && legacy.exist?
    end
  end
  content = wrapper_template.sub("__SCRIPT__", script)
  write_file(dest, content, dry_run: options[:dry_run])
  FileUtils.chmod(0o755, dest) if dest.file? && !options[:dry_run]
end

# Generic static web check helper (optional; stack may call product-local check_web.rb)
copy_if_missing(
  kit_root / "scripts" / "check_static_web.rb",
  product_root / "scripts" / "check_static_web.rb",
  dry_run: options[:dry_run]
)
FileUtils.chmod(0o755, product_root / "scripts" / "check_static_web.rb") if (product_root / "scripts" / "check_static_web.rb").file? && !options[:dry_run]

# --- adapters ---
if options[:install_adapters]
  [
    ["adapters/claude/CLAUDE.md", "CLAUDE.md"],
    ["adapters/cursor/.cursor/rules/agent-delivery.mdc", ".cursor/rules/agent-delivery.mdc"],
    ["adapters/grok/skills/agent-delivery/SKILL.md", ".grok/skills/agent-delivery/SKILL.md"],
  ].each do |from, to|
    src = kit_root / from
    src = kit_root / "#{from}.stub" unless src.file?
    next unless src.file?
    copy_if_missing(src, product_root / to, dry_run: options[:dry_run])
  end
end

# --- VERSION_KIT ---
write_file(product_root / "VERSION_KIT", "#{kit_version}\n", dry_run: options[:dry_run])

if options[:mode] == "copy" && !options[:dry_run]
  vendor = product_root / "vendor" / "agent-delivery-kit"
  unless vendor.exist?
    FileUtils.mkdir_p(vendor)
    Dir.children(kit_root).each do |child|
      next if child == "examples"
      FileUtils.cp_r(kit_root / child, vendor / child)
    end
    log("vendored kit -> #{vendor}", dry_run: false)
  end
end

puts ""
puts "Adopted kit into #{product_root}"
puts "  name:    #{options[:name]}"
puts "  preset:  #{options[:preset]}"
puts "  mode:    #{options[:mode]}"
puts "  kit:     #{kit_path_value}"
puts "Next:"
puts "  cd #{product_root}"
puts "  ruby scripts/doctor.rb"
puts "  ruby scripts/validate_workflow.rb"
puts "  # dry-run delivery on one task:"
puts "  ruby scripts/deliver.rb <task>"
puts "  # previous scripts (if any): scripts/legacy/"
