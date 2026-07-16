# frozen_string_literal: true

require "date"
require "yaml"

module AgentDelivery
  module FrontMatter
    module_function

    def parse_file(path, errors = nil)
      lines = File.readlines(path)
      unless lines.first&.strip == "---"
        errors << "#{path}: missing YAML front matter" if errors
        return {}
      end

      closing = lines[1..]&.index { |line| line.strip == "---" }
      unless closing
        errors << "#{path}: unterminated YAML front matter" if errors
        return {}
      end

      YAML.safe_load(lines[1..closing].join, permitted_classes: [Date], aliases: false) || {}
    rescue Psych::SyntaxError => e
      errors << "#{path}: invalid YAML (#{e.message.lines.first.strip})" if errors
      {}
    end

    def parse_file!(path)
      errors = []
      data = parse_file(path, errors)
      abort errors.join("\n") unless errors.empty?
      data
    end
  end
end
