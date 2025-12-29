# frozen_string_literal: true

module EvidenceProbe
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class APIError < Error; end

  # RetriableError for transient failures that should be retried
  class RetriableError < Error
    attr_reader :wait_time

    def initialize(message, wait_time = nil)
      super(message)
      @wait_time = wait_time
    end
  end
end
