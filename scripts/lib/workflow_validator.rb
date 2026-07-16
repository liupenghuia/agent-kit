# frozen_string_literal: true

require "pathname"
require_relative "front_matter"
require_relative "status_machines"
require_relative "product_config"

module AgentDelivery
  class WorkflowValidator
    include StatusMachines

    def initialize(product)
      @product = product
      @root = product.root
      @errors = []
    end

    def run!
      idea_paths = Dir[@root.join("ideas", "*.md")].reject { |p| File.basename(p) == "template.md" }
      task_paths = Dir[@root.join("tasks", "*.md")].reject { |p| File.basename(p) == "template.md" }
      issue_paths = Dir[@root.join("issues", "*.md")].reject { |p| File.basename(p) == "template.md" }

      ideas = idea_paths.to_h { |path| [path, FrontMatter.parse_file(path, @errors)] }
      tasks = task_paths.to_h { |path| [path, FrontMatter.parse_file(path, @errors)] }
      issues = issue_paths.to_h { |path| [path, FrontMatter.parse_file(path, @errors)] }

      ids = {}
      ideas.merge(tasks).merge(issues).each do |path, data|
        id = data["id"]
        next unless id
        @errors << "#{path}: duplicate id #{id} (also #{ids[id]})" if ids.key?(id)
        ids[id] = path
      end

      idea_by_id = ideas.each_with_object({}) { |(path, data), index| index[data["id"]] = [path, data] if data["id"] }
      task_by_id = tasks.each_with_object({}) { |(path, data), index| index[data["id"]] = [path, data] if data["id"] }
      issue_by_id = issues.each_with_object({}) { |(path, data), index| index[data["id"]] = [path, data] if data["id"] }

      validate_ideas(ideas, task_by_id)
      validate_tasks(tasks, idea_by_id, task_by_id, issue_by_id)
      validate_issues(issues, task_by_id)

      if @errors.empty?
        puts "Workflow validation passed (#{ideas.length} ideas, #{tasks.length} tasks, #{issues.length} issues)."
        return 0
      end

      warn "Workflow validation failed:"
      @errors.each { |error| warn "- #{error.sub(@root.to_s + '/', '')}" }
      1
    end

    private

    def require_fields(path, data, fields)
      fields.each { |field| @errors << "#{path}: missing #{field}" unless data.key?(field) }
    end

    def validate_ideas(ideas, task_by_id)
      ideas.each do |path, idea|
        require_fields(path, idea, %w[id title status priority owner decision_owner created updated promoted_tasks])
        @errors << "#{path}: invalid idea id #{idea['id']}" unless idea["id"].to_s.match?(/\AIDEA-\d{8}-\d{3}\z/)
        @errors << "#{path}: invalid status #{idea['status']}" unless IDEA_STATUSES.include?(idea["status"])
        @errors << "#{path}: invalid priority #{idea['priority']}" unless PRIORITIES.include?(idea["priority"])
        @errors << "#{path}: idea owner must be Product Agent" unless idea["owner"] == "Product Agent"
        if idea["decision_owner"].nil? || idea["decision_owner"].to_s.strip.empty?
          @errors << "#{path}: decision_owner is required"
        end
        @errors << "#{path}: promoted_tasks must be a list" unless idea["promoted_tasks"].is_a?(Array)
        if idea["status"] == "Promoted" && Array(idea["promoted_tasks"]).empty?
          @errors << "#{path}: Promoted requires at least one promoted task"
        end

        Array(idea["promoted_tasks"]).each do |task_id|
          task = task_by_id[task_id]
          @errors << "#{path}: unknown promoted task #{task_id}" unless task
          if idea["status"] == "Promoted" && task && task.last["source_idea"] != idea["id"]
            @errors << "#{path}: promoted task #{task_id} does not link source idea #{idea['id']}"
          end
        end
      end
    end

    def validate_tasks(tasks, idea_by_id, task_by_id, issue_by_id)
      frontend_keys = @product.frontend_target_keys
      frontend_keys = %w[miniprogram web] if frontend_keys.empty?
      implementation_scopes = @product.implementation_scopes
      all_scopes = ProductConfig::DEFAULT_ALL_SCOPES
      owners = @product.owners

      tasks.each do |path, task|
        require_fields(path, task, %w[id title status priority owner created updated source_idea depends_on linked_issues required_scopes frontend_targets frontend_target_status scope_status release_required])
        @errors << "#{path}: invalid task id #{task['id']}" unless task["id"].to_s.match?(/\ATASK-\d{8}-\d{3}\z/)
        @errors << "#{path}: invalid status #{task['status']}" unless TASK_STATUSES.include?(task["status"])
        @errors << "#{path}: invalid priority #{task['priority']}" unless PRIORITIES.include?(task["priority"])
        @errors << "#{path}: invalid owner #{task['owner']}" unless owners.include?(task["owner"])

        source_idea = task["source_idea"]
        if source_idea
          idea = idea_by_id[source_idea]
          @errors << "#{path}: unknown source idea #{source_idea}" unless idea
          if idea && !["Approved", "Promoted"].include?(idea.last["status"])
            @errors << "#{path}: source idea #{source_idea} must be Approved or Promoted"
          end
          if idea&.last&.dig("status") == "Promoted" && !Array(idea.last["promoted_tasks"]).include?(task["id"])
            @errors << "#{path}: source idea #{source_idea} does not link task #{task['id']}"
          end
        end

        required = task["required_scopes"]
        frontend_targets = task["frontend_targets"]
        frontend_target_status = task["frontend_target_status"]
        scopes = task["scope_status"]
        unless required.is_a?(Hash) && frontend_targets.is_a?(Hash) && frontend_target_status.is_a?(Hash) && scopes.is_a?(Hash)
          @errors << "#{path}: required_scopes, frontend_targets, frontend_target_status, and scope_status must be mappings"
          next
        end

        implementation_scopes.each do |scope|
          @errors << "#{path}: required_scopes missing #{scope}" unless [true, false].include?(required[scope])
        end
        frontend_keys.each do |target|
          @errors << "#{path}: frontend_targets missing #{target}" unless [true, false].include?(frontend_targets[target])
          @errors << "#{path}: invalid or missing frontend_target_status.#{target}" unless SCOPE_STATUSES.include?(frontend_target_status[target])
          if frontend_targets[target] == false && frontend_target_status[target] != "N/A"
            @errors << "#{path}: non-required frontend target #{target} must be N/A"
          elsif frontend_targets[target] == true && frontend_target_status[target] == "N/A"
            @errors << "#{path}: required frontend target #{target} cannot be N/A"
          end
        end
        if required["frontend"] == false && frontend_targets.values.any? { |needed| needed == true }
          @errors << "#{path}: frontend_targets cannot be required when frontend scope is false"
        elsif required["frontend"] == true && frontend_targets.values.none? { |needed| needed == true }
          @errors << "#{path}: frontend scope requires at least one frontend target"
        end
        all_scopes.each do |scope|
          @errors << "#{path}: invalid or missing scope_status.#{scope}" unless SCOPE_STATUSES.include?(scopes[scope])
        end
        implementation_scopes.each do |scope|
          if required[scope] == false && scopes[scope] != "N/A"
            @errors << "#{path}: non-required #{scope} scope must be N/A"
          elsif required[scope] == true && scopes[scope] == "N/A"
            @errors << "#{path}: required #{scope} scope cannot be N/A"
          end
        end

        if task["release_required"] == false && scopes["release"] != "N/A"
          @errors << "#{path}: release scope must be N/A when release_required is false"
        elsif task["release_required"] == true && scopes["release"] == "N/A"
          @errors << "#{path}: release scope cannot be N/A when release_required is true"
        elsif ![true, false].include?(task["release_required"])
          @errors << "#{path}: release_required must be true or false"
        end

        architecture_ready = [
          "Ready for Implementation", "In Progress", "Ready for Test", "Test Failed",
          "Ready for Retest", "Ready for Release", "Released", "Done"
        ].include?(task["status"])
        if architecture_ready && [scopes["product"], scopes["architecture"]] != ["Done", "Done"]
          @errors << "#{path}: product and architecture scopes must be Done"
        end

        implementation_done = ["Ready for Test", "Test Failed", "Ready for Retest", "Ready for Release", "Released", "Done"].include?(task["status"])
        if implementation_done
          required.select { |_scope, needed| needed }.each_key do |scope|
            @errors << "#{path}: required #{scope} scope must be Done at #{task['status']}" unless scopes[scope] == "Done"
          end
          frontend_keys.each do |target|
            if frontend_targets[target] && frontend_target_status[target] != "Done"
              @errors << "#{path}: required frontend target #{target} must be Done at #{task['status']}"
            end
          end
        end

        if ["Ready for Release", "Released", "Done"].include?(task["status"])
          @errors << "#{path}: test scope must be Done at #{task['status']}" unless scopes["test"] == "Done"
        end
        if task["status"] == "Done" && task["release_required"] && scopes["release"] != "Done"
          @errors << "#{path}: release scope must be Done"
        end

        if task["status"] == "Blocked"
          %w[blocked_reason blocked_since unblock_owner unblock_condition].each do |field|
            @errors << "#{path}: #{field} is required while Blocked" if task[field].nil? || task[field].to_s.strip.empty?
          end
        end

        @errors << "#{path}: depends_on must be a list" unless task["depends_on"].is_a?(Array)
        @errors << "#{path}: linked_issues must be a list" unless task["linked_issues"].is_a?(Array)
        if ["Test Failed", "Ready for Retest"].include?(task["status"]) && Array(task["linked_issues"]).empty?
          @errors << "#{path}: #{task['status']} requires at least one linked issue"
        end

        Array(task["depends_on"]).each do |dependency|
          dep = task_by_id[dependency]
          @errors << "#{path}: unknown dependency #{dependency}" unless dep
          @errors << "#{path}: dependency #{dependency} is not Done" if task["status"] == "Done" && dep && dep.last["status"] != "Done"
        end
        Array(task["linked_issues"]).each do |issue_id|
          issue = issue_by_id[issue_id]
          @errors << "#{path}: unknown linked issue #{issue_id}" unless issue
          @errors << "#{path}: linked issue #{issue_id} is not Closed" if task["status"] == "Done" && issue && issue.last["status"] != "Closed"
          if task["status"] == "Ready for Retest" && issue && !["Ready for Retest", "Closed"].include?(issue.last["status"])
            @errors << "#{path}: linked issue #{issue_id} is not ready for retest or closed"
          end
        end
      end
    end

    def validate_issues(issues, task_by_id)
      owners = @product.owners
      issues.each do |path, issue|
        require_fields(path, issue, %w[id title status severity owner task found_by created updated])
        @errors << "#{path}: invalid issue id #{issue['id']}" unless issue["id"].to_s.match?(/\AISSUE-\d{8}-\d{3}\z/)
        @errors << "#{path}: invalid status #{issue['status']}" unless ISSUE_STATUSES.include?(issue["status"])
        @errors << "#{path}: invalid severity #{issue['severity']}" unless PRIORITIES.include?(issue["severity"])
        @errors << "#{path}: invalid owner #{issue['owner']}" unless owners.include?(issue["owner"])
        @errors << "#{path}: unknown task #{issue['task']}" unless task_by_id.key?(issue["task"])
        related_task = task_by_id[issue["task"]]&.last
        if related_task && !Array(related_task["linked_issues"]).include?(issue["id"])
          @errors << "#{path}: task #{issue['task']} does not link issue #{issue['id']}"
        end
      end
    end
  end
end
