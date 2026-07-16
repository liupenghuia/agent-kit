#!/usr/bin/env ruby
# frozen_string_literal: true

# Scaffold a product repository that uses agent-delivery-kit.
#
# Usage:
#   ruby scripts/init_product.rb --path DIR --name SLUG [options]
#   ruby scripts/init_product.rb --path ./demo --name demo --preset api-web

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

STACK_DIR_MAP = {
  backend: "backend",
  web: "frontend/web",
  miniprogram: "frontend/miniprogram",
  ios: "mobile/ios",
  android: "mobile/android",
}.freeze

options = {
  path: nil,
  name: nil,
  display_name: nil,
  mode: "link",
  kit_path: KIT_ROOT.to_s,
  preset: "api-web",
  backend: nil,
  web: nil,
  miniprogram: nil,
  force: false,
  locales: ["zh"],
  decision_owner: "User",
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/init_product.rb --path DIR --name SLUG [options]"
  opts.on("--path DIR", "Product repository root to create") { |v| options[:path] = v }
  opts.on("--name SLUG", "Product slug") { |v| options[:name] = v }
  opts.on("--display-name NAME", "Human title") { |v| options[:display_name] = v }
  opts.on("--mode MODE", "link or copy (default: link)") { |v| options[:mode] = v }
  opts.on("--kit-path DIR", "Path to agent-delivery-kit") { |v| options[:kit_path] = v }
  opts.on("--preset NAME", "api-web | api-miniprogram | api-web-miniprogram | docs-only") { |v| options[:preset] = v }
  opts.on("--backend STACK", "Override backend stack id") { |v| options[:backend] = v }
  opts.on("--web STACK", "Override web stack id") { |v| options[:web] = v }
  opts.on("--miniprogram STACK", "Enable miniprogram stack id") { |v| options[:miniprogram] = v }
  opts.on("--no-miniprogram", "Force miniprogram off") { options[:miniprogram] = false }
  opts.on("--force", "Allow non-empty target directory") { options[:force] = true }
  opts.on("--decision-owner NAME", "Idea decision owner") { |v| options[:decision_owner] = v }
  opts.on("-h", "--help") { puts opts; exit 0 }
end
parser.parse!

abort parser.to_s if options[:path].to_s.empty? || options[:name].to_s.empty?
abort "unknown preset: #{options[:preset]}" unless PRESETS.key?(options[:preset])
abort "mode must be link or copy" unless %w[link copy].include?(options[:mode])

product_root = Pathname(options[:path]).expand_path
kit_root = Pathname(options[:kit_path]).expand_path
abort "kit not found: #{kit_root}" unless kit_root.join("VERSION").file? || kit_root.join("core").directory?

if product_root.exist?
  entries = product_root.children.reject { |p| p.basename.to_s.start_with?(".") }
  abort "target not empty: #{product_root} (use --force)" if !entries.empty? && !options[:force]
else
  FileUtils.mkdir_p(product_root)
end

preset = PRESETS[options[:preset]]
scopes = preset[:scopes].dup
targets = preset[:frontend_targets].dup
stacks = preset[:stacks].dup

stacks[:backend] = options[:backend] if options[:backend]
stacks[:web] = options[:web] if options[:web]
if options[:miniprogram] == false
  targets[:miniprogram] = false
  stacks.delete(:miniprogram)
elsif options[:miniprogram]
  targets[:miniprogram] = true
  stacks[:miniprogram] = options[:miniprogram]
end

targets[:web] = true if stacks[:web]
scopes[:backend] = true if stacks[:backend]
scopes[:frontend] = true if targets.values.any?

display = options[:display_name] || options[:name]
kit_version = begin
  (kit_root / "VERSION").read.strip
rescue StandardError
  "0.0.0-dev"
end

def copy_file(src, dest, force:)
  FileUtils.mkdir_p(dest.dirname)
  if dest.exist? && !force
    warn "skip existing #{dest}"
    return
  end
  FileUtils.cp(src, dest)
end

def write_file(dest, content, force:)
  FileUtils.mkdir_p(dest.dirname)
  if dest.exist? && !force
    warn "skip existing #{dest}"
    return
  end
  dest.write(content)
end

def render(template, vars)
  out = template.dup
  vars.each { |k, v| out.gsub!("{{#{k}}}", v.to_s) }
  out
end

# --- 1) Core docs & templates ---
doc_files = %w[
  delivery-workflow.md
  code-quality-prerequisites.md
  iterative-implementation-guidelines.md
  product-discovery.md
  product-request-template.md
  testing.md
  client-architecture.md
]

doc_files.each do |name|
  src = kit_root / "docs" / name
  next unless src.file?
  copy_file(src, product_root / "docs" / name, force: options[:force])
end

arch_stub = kit_root / "docs" / "architecture.md.stub"
copy_file(arch_stub, product_root / "docs" / "architecture.md", force: options[:force]) if arch_stub.file?

%w[requirements.md.stub database.md.stub openapi.yaml.stub].each do |stub|
  src = kit_root / "templates" / "docs" / stub
  next unless src.file?
  dest_name = stub.sub(/\.stub\z/, "")
  copy_file(src, product_root / "docs" / dest_name, force: options[:force])
end

[
  ["templates/ideas/template.md", "ideas/template.md"],
  ["templates/tasks/template.md", "tasks/template.md"],
  ["templates/issues/template.md", "issues/template.md"],
  ["core/COMMANDS.md", "COMMANDS.md"],
].each do |from, to|
  src = kit_root / from
  copy_file(src, product_root / to, force: options[:force]) if src.file?
end

docs_agents = <<~MD
  # Docs agents

  Product and Architect own product truth docs under `docs/`.
  Process docs originate from agent-delivery-kit; keep product facts here.
MD
write_file(product_root / "docs" / "AGENTS.md", docs_agents, force: options[:force])

# --- 2) Stack plugins ---
stacks.each do |role, stack_id|
  stack_path = kit_root / "stacks" / stack_id
  abort "stack not found: #{stack_id}" unless stack_path.directory?

  rel = STACK_DIR_MAP[role] || role.to_s
  dest = product_root / rel
  FileUtils.mkdir_p(dest)

  agents = stack_path / "AGENTS.md"
  copy_file(agents, dest / "AGENTS.md", force: options[:force]) if agents.file?

  Dir[stack_path.join("**", "*")].each do |file|
    next if File.directory?(file)
    rel_file = Pathname(file).relative_path_from(stack_path).to_s
    next if rel_file == "AGENTS.md" || rel_file == "checks.yaml"
    next unless rel_file.end_with?(".stub")
    out = dest / rel_file.sub(/\.stub\z/, "")
    copy_file(Pathname(file), out, force: options[:force])
  end
end

if scopes[:frontend]
  fe_agents = kit_root / "roles" / "frontend.md"
  write_file(
    product_root / "frontend" / "AGENTS.md",
    (fe_agents.file? ? fe_agents.read : "# Frontend Agent\n"),
    force: options[:force]
  )
  write_file(product_root / "frontend" / "HISTORY.md", "# Frontend target history\n\n", force: options[:force])
end

if scopes[:backend]
  be = kit_root / "roles" / "backend.md"
  # Prefer stack AGENTS already copied; add tests AGENTS
end

test_agents = kit_root / "roles" / "test.md"
write_file(
  product_root / "tests" / "AGENTS.md",
  (test_agents.file? ? test_agents.read : "# Test Agent\n"),
  force: options[:force]
)

# --- 3) Merge delivery checks from stacks ---
checks = [{ "id" => "workflow", "cmd" => %w[ruby scripts/validate_workflow.rb] }]
stacks.each_value do |stack_id|
  checks_file = kit_root / "stacks" / stack_id / "checks.yaml"
  next unless checks_file.file?
  fragment = YAML.safe_load(checks_file.read, aliases: false) || {}
  Array(fragment["checks"]).each { |c| checks << c }
end

# Always store an absolute kit path in link mode. Relative paths break on macOS when
# tmpdirs live under /var (realpath /private/var) while the kit lives under /Users.
kit_path_value =
  if options[:mode] == "copy"
    "vendored"
  else
    kit_root.expand_path.to_s
  end

# --- 4) product.yaml ---
product = {
  "kit_version" => kit_version,
  "name" => options[:name],
  "display_name" => display,
  "locales" => options[:locales],
  "decision_owner" => options[:decision_owner],
  "scopes" => scopes.transform_keys(&:to_s),
  "frontend_targets" => targets.transform_keys(&:to_s),
  "stacks" => stacks.transform_keys(&:to_s),
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
    "evidence_root" => "/tmp/agent-delivery/#{options[:name]}",
    "command_timeout_sec" => 180,
    "checks" => checks,
    "human_gates" => [
      { "id" => "production-deploy", "description" => "Production deploy requires explicit approval" },
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
    "test" => "Test Agent",
    "orchestrator" => "Orchestrator Agent",
  },
}

write_file(
  product_root / "product.yaml",
  "# Generated by agent-delivery-kit init_product.rb\n" + product.to_yaml,
  force: options[:force]
)

# --- 5) Root AGENTS.md ---
agents_tpl_path = kit_root / "core" / "AGENTS.root.md"
if agents_tpl_path.file?
  agents = render(agents_tpl_path.read, {
    "PRODUCT_NAME" => display,
    "PRODUCT_SLUG" => options[:name],
    "KIT_VERSION" => kit_version,
    "KIT_PATH" => options[:mode] == "link" ? kit_path_value : "./vendor/agent-delivery-kit",
    "QUALITY_MODE" => "code-first",
  })
  write_file(product_root / "AGENTS.md", agents, force: options[:force])
end

# --- 6) Thin script wrappers ---
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
  content = wrapper_template.sub("__SCRIPT__", script)
  dest = product_root / "scripts" / script
  write_file(dest, content, force: options[:force])
  FileUtils.chmod(0o755, dest) if dest.file?
end

# --- 7) Metadata ---
write_file(product_root / "VERSION_KIT", "#{kit_version}\n", force: options[:force])

readme_stub = kit_root / "templates" / "product" / "README.product.md.stub"
if readme_stub.file?
  write_file(
    product_root / "README.md",
    render(readme_stub.read, "PRODUCT_NAME" => display, "PRODUCT_SLUG" => options[:name]),
    force: options[:force]
  )
end

if options[:mode] == "copy"
  vendor = product_root / "vendor" / "agent-delivery-kit"
  FileUtils.mkdir_p(vendor.dirname)
  FileUtils.rm_rf(vendor) if options[:force] && vendor.exist?
  unless vendor.exist?
    FileUtils.mkdir_p(vendor)
    # Copy kit contents without nested vendor/examples noise if needed
    Dir.children(kit_root).each do |child|
      next if child == "examples"
      src = kit_root / child
      FileUtils.cp_r(src, vendor / child)
    end
  end
end

# Ensure empty issues dir exists
FileUtils.mkdir_p(product_root / "issues")

puts "Initialized product at #{product_root}"
puts "  name:    #{options[:name]}"
puts "  preset:  #{options[:preset]}"
puts "  mode:    #{options[:mode]}"
puts "  stacks:  #{stacks.inspect}"
puts "Next:"
puts "  cd #{product_root}"
puts "  ruby scripts/doctor.rb"
puts "  # then: 想法 <name>  /  idea <name>"
