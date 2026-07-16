# frozen_string_literal: true

require "fileutils"
require "open3"
require "optparse"
require "pathname"
require "securerandom"
require "timeout"
require "yaml"
require_relative "kit_paths"
require_relative "product_config"
require_relative "front_matter"

module AgentDelivery
  class DeliveryRunner
    def self.cli!(argv)
      new.cli!(argv)
    end

    def cli!(argv)
      product_root, = KitPaths.ensure_env!
      @product = ProductConfig.load!(product_root)
      @root = product_root

      options = {
        max_rounds: @product.max_rounds,
        repair_command: ENV["DELIVERY_REPAIR_COMMAND"],
      }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: ruby scripts/deliver.rb TASK [options]"
        opts.on("--max-rounds N", Integer, "Maximum repair rounds") { |n| options[:max_rounds] = n }
        opts.on("--repair-command COMMAND", "Shell command between failed rounds") { |c| options[:repair_command] = c }
        opts.on("--help") { puts opts; exit 0 }
      end
      parser.parse!(argv)

      task_name = argv.shift
      abort parser.to_s unless task_name
      abort "--max-rounds must be positive" unless options[:max_rounds].positive?

      task_file = resolve_task(task_name)
      abort "task not found: #{task_name}" unless task_file

      task = FrontMatter.parse_file!(task_file)
      run_id = "#{Time.now.strftime('%Y%m%d-%H%M%S')}-#{SecureRandom.hex(3)}"
      run_dir = Pathname(@product.evidence_root).join(task["id"].to_s, run_id)
      FileUtils.mkdir_p(run_dir)

      rounds = {}
      final_results = []
      (1..options[:max_rounds]).each do |round|
        round_dir = run_dir.join("round-#{round}")
        FileUtils.mkdir_p(round_dir)
        puts "[delivery] round #{round}/#{options[:max_rounds]}: running checks"
        final_results = run_round(task, round_dir)
        rounds[round] = final_results
        failures = final_results.reject { |r| r[:success] }
        if failures.empty?
          puts "[delivery] round #{round}: passed"
          break
        end

        puts "[delivery] round #{round}: #{failures.length} check(s) failed"
        unless options[:repair_command]
          puts "[delivery] no repair command configured; stopping with evidence"
          break
        end
        break if round == options[:max_rounds]

        repair = execute(
          "repair-round-#{round}",
          ["sh", "-lc", options[:repair_command]],
          cwd: @root,
          env: {
            "DELIVERY_TASK" => task_file.to_s,
            "DELIVERY_ROUND" => round.to_s,
            "DELIVERY_RUN_DIR" => run_dir.to_s,
            "PRODUCT_ROOT" => @root.to_s,
            "KIT_ROOT" => ENV["KIT_ROOT"].to_s,
          },
          log_dir: run_dir
        )
        rounds[round] << repair
        unless repair[:success]
          puts "[delivery] repair command failed; stopping with evidence"
          break
        end
      end

      report = run_dir.join("report.md")
      write_report(report, task, run_id, rounds, final_results)
      puts "[delivery] report: #{report}"
      exit(final_results.all? { |r| r[:success] } ? 0 : 1)
    end

    private

    def resolve_task(name)
      direct = @root.join("tasks", "#{name}.md")
      return direct if direct.file?

      Dir[@root.join("tasks", "*.md")].map { |p| Pathname(p) }.find do |path|
        title = path.read.match(/^title:\s*["']?(.+?)["']?\s*$/)&.[](1)
        title&.strip == name
      end
    end

    def run_round(task, log_dir)
      results = []
      @product.applicable_checks(task: task).each do |check|
        id = check["id"].to_s
        cmd = Array(check["cmd"]).map(&:to_s)
        cwd = check["cwd"] ? @root.join(check["cwd"]) : @root
        results << execute(id, cmd, cwd: cwd, log_dir: log_dir)
      end
      results
    end

    def execute(label, command, cwd:, log_dir:, env: {})
      log = log_dir.join("#{label.gsub(/[^a-zA-Z0-9_-]/, '_')}.log")
      output = ""
      status = nil
      timeout = @product.command_timeout_sec
      begin
        Timeout.timeout(timeout) do
          out, err, status = Open3.capture3(env, *command, chdir: cwd.to_s)
          output = "#{out}#{err}"
        end
      rescue Timeout::Error
        output = "command timed out after #{timeout}s\n"
        status = Struct.new(:success?).new(false)
      rescue Errno::ENOENT => e
        output = "#{e.message}\n"
        status = Struct.new(:success?).new(false)
      end
      log.write(output)
      {
        label: label,
        command: command.join(" "),
        success: status&.success? || false,
        log: log.to_s,
        output: output,
      }
    end

    def write_report(path, task, run_id, rounds, final_results)
      lines = [
        "# Delivery Run #{run_id}",
        "",
        "- Task: `#{task['id']}`",
        "- Product: `#{@product.name}`",
        "- Status: #{final_results.all? { |r| r[:success] } ? 'Passed' : 'Failed'}",
        "",
        "## Rounds",
        "",
      ]
      rounds.each do |round, results|
        lines << "### Round #{round}"
        results.each do |result|
          marker = result[:success] ? "PASS" : "FAIL"
          lines << "- [#{marker}] `#{result[:label]}`: `#{result[:command]}`"
          lines << "  Log: `#{result[:log]}`"
        end
        lines << ""
      end
      if @product.human_gates.any?
        lines << "## Human gates (not auto-passed)"
        lines << ""
        @product.human_gates.each do |gate|
          lines << "- `#{gate['id']}`: #{gate['description']}"
        end
        lines << ""
      end
      path.write(lines.join("\n"))
    end
  end
end
