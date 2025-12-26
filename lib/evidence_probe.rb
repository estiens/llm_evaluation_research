# frozen_string_literal: true

require_relative 'evidence_probe/configuration'
require_relative 'evidence_probe/errors'
require_relative 'evidence_probe/client'
require_relative 'evidence_probe/role'
require_relative 'evidence_probe/scenario'
require_relative 'evidence_probe/probe'
require_relative 'evidence_probe/judge'
require_relative 'evidence_probe/response_analyzer'
require_relative 'evidence_probe/report_generator'
require_relative 'evidence_probe/dsl'

module EvidenceProbe
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end

    def reset!
      @configuration = nil
    end

    # DSL convenience methods
    def probe(name = nil, &block)
      DSL.probe(name, &block)
    end

    def quick_probe(**options)
      DSL.quick_probe(**options)
    end
  end
end
