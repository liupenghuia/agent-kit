#!/usr/bin/env ruby
# frozen_string_literal: true

# Run product.yaml delivery.checks for a task (optionally multi-round with repair).
# Usage: ruby scripts/deliver.rb TASK [--max-rounds N]

require_relative "lib/delivery_runner"

AgentDelivery::DeliveryRunner.cli!(ARGV)
