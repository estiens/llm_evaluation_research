# frozen_string_literal: true

module EvidenceProbe
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class APIError < Error; end
end
