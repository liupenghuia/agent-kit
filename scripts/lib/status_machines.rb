# frozen_string_literal: true

module AgentDelivery
  module StatusMachines
    IDEA_STATUSES = [
      "Captured", "Discovering", "Ready for Review", "Approved", "Parked", "Rejected", "Promoted"
    ].freeze

    TASK_STATUSES = [
      "Draft", "Ready for Architecture", "Ready for Implementation", "In Progress",
      "Blocked", "Ready for Test", "Test Failed", "Ready for Retest",
      "Ready for Release", "Released", "Done", "Cancelled"
    ].freeze

    ISSUE_STATUSES = [
      "Open", "Assigned", "Fixing", "Ready for Retest", "Retest Failed", "Closed"
    ].freeze

    SCOPE_STATUSES = ["N/A", "Pending", "In Progress", "Blocked", "Done"].freeze
    PRIORITIES = %w[P0 P1 P2 P3].freeze
  end
end
