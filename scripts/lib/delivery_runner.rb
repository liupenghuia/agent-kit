# frozen_string_literal: true

require "fileutils"
require "net/http"
require "open3"
require "optparse"
require "pathname"
require "securerandom"
require "socket"
require "timeout"
require "uri"
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
        next if path.basename.to_s == "template.md"
        title = path.read.match(/^title:\s*["']?(.+?)["']?\s*$/)&.[](1)
        title&.strip == name
      end
    end

    def run_round(task, log_dir)
      results = []
      @product.applicable_checks(task: task).each do |check|
        results.concat(run_check(check, log_dir))
      end
      results
    end

    def run_check(check, log_dir)
      type = (check["type"] || "cmd").to_s
      case type
      when "cmd", "command"
        run_cmd_check(check, log_dir)
      when "service_http", "http_service"
        [run_service_http_check(check, log_dir)]
      else
        [{
          label: check["id"].to_s,
          command: "unsupported type=#{type}",
          success: false,
          log: log_dir.join("#{sanitize(check['id'])}.log").to_s,
          output: "unsupported check type: #{type}\n",
        }].tap { |r| Pathname(r[0][:log]).write(r[0][:output]) }
      end
    end

    def run_cmd_check(check, log_dir)
      id = check["id"].to_s
      base_cmd = Array(check["cmd"]).map(&:to_s)
      cwd = resolve_cwd(check)
      env = stringify_env(check["env"])
      glob = check["glob"].to_s.strip

      if glob.empty?
        return [execute(id, base_cmd, cwd: cwd, env: env, log_dir: log_dir)]
      end

      files = expand_glob(glob, cwd)
      if files.empty?
        allow_empty = check["allow_empty"] == true
        output = "glob matched 0 files: #{glob} (cwd=#{cwd})\n"
        log = log_dir.join("#{sanitize(id)}.log")
        log.write(output)
        return [{
          label: id,
          command: "#{base_cmd.join(' ')} <glob:#{glob}>",
          success: allow_empty,
          log: log.to_s,
          output: output,
        }]
      end

      files.each_with_index.map do |file, index|
        # Paths relative to cwd keep command logs readable.
        rel = relative_path(file, cwd)
        cmd = base_cmd + [rel]
        execute("#{id}-#{index}", cmd, cwd: cwd, env: env, log_dir: log_dir)
      end
    end

    def run_service_http_check(check, log_dir)
      id = check["id"].to_s
      cwd = resolve_cwd(check)
      port = free_port
      start_cmd = Array(check["start"] || check["cmd"]).map { |part| part.to_s.gsub("{{port}}", port.to_s) }
      env = stringify_env(check["env"]).transform_values { |v| v.to_s.gsub("{{port}}", port.to_s) }
      health_url = check["health_url"].to_s.gsub("{{port}}", port.to_s)
      ready_timeout = Integer(check["ready_timeout_sec"] || 15)
      log = log_dir.join("#{sanitize(id)}.service.log")

      if start_cmd.empty? || health_url.empty?
        output = "service_http requires start (or cmd) and health_url\n"
        log.write(output)
        return {
          label: id,
          command: "service_http",
          success: false,
          log: log.to_s,
          output: output,
        }
      end

      process = nil
      begin
        io = File.open(log, "w")
        process = Process.spawn(env, *start_cmd, chdir: cwd.to_s, out: io, err: [:child, :out])
        io.close
        wait_for_http(health_url, process, ready_timeout)
        {
          label: id,
          command: "GET #{health_url} (start: #{start_cmd.join(' ')})",
          success: true,
          log: log.to_s,
          output: "healthy\n",
        }
      rescue StandardError => e
        output = "#{e.message}\n"
        File.open(log, "a") { |f| f.write(output) } if log.exist?
        log.write(output) unless log.exist?
        {
          label: id,
          command: "GET #{health_url} (start: #{start_cmd.join(' ')})",
          success: false,
          log: log.to_s,
          output: output,
        }
      ensure
        stop_service(process)
      end
    end

    def resolve_cwd(check)
      check["cwd"] ? @root.join(check["cwd"]) : @root
    end

    def expand_glob(glob, cwd)
      pattern = Pathname(glob).absolute? ? glob : cwd.join(glob).to_s
      Dir.glob(pattern).map { |p| Pathname(p) }.select(&:file?).sort
    end

    def relative_path(path, cwd)
      path = Pathname(path).expand_path
      cwd = Pathname(cwd).expand_path
      path.relative_path_from(cwd).to_s
    rescue ArgumentError
      path.to_s
    end

    def stringify_env(env)
      return {} unless env.is_a?(Hash)
      env.each_with_object({}) { |(k, v), acc| acc[k.to_s] = v.to_s }
    end

    def free_port
      socket = TCPServer.new("127.0.0.1", 0)
      port = socket.addr[1]
      socket.close
      port
    end

    def process_alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end

    def wait_for_http(url, process, timeout_sec)
      deadline = Time.now + timeout_sec
      last_error = nil
      while Time.now < deadline
        raise "service process exited before healthy" if process && !process_alive?(process)
        begin
          uri = URI(url)
          res = Net::HTTP.start(uri.host, uri.port, open_timeout: 1, read_timeout: 2) do |http|
            http.get(uri.request_uri)
          end
          return true if res.is_a?(Net::HTTPSuccess)
          last_error = "HTTP #{res.code}"
        rescue StandardError => e
          last_error = e.message
        end
        sleep 0.2
      end
      raise "health check timed out after #{timeout_sec}s (#{url}): #{last_error}"
    end

    def stop_service(process)
      return unless process
      Process.kill("TERM", process) if process_alive?(process)
      Timeout.timeout(5) { Process.wait(process) }
    rescue StandardError
      begin
        Process.kill("KILL", process) if process_alive?(process)
        Process.wait(process)
      rescue StandardError
        nil
      end
    end

    def execute(label, command, cwd:, log_dir:, env: {})
      log = log_dir.join("#{sanitize(label)}.log")
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

    def sanitize(label)
      label.to_s.gsub(/[^a-zA-Z0-9_-]/, "_")
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
