# frozen_string_literal: true

module EvidenceProbe
  class Configuration
    attr_accessor :api_key, :api_url, :default_models, :judge_model,
                  :output_dir, :verbose, :max_retries, :timeout

    def initialize
      @api_key = ENV['OPENROUTER_API_KEY'] || ENV['QUALSPEC_API_KEY']
      @api_url = ENV['OPENROUTER_API_URL'] || 'https://openrouter.ai/api/v1'
      @default_models = %w[
        anthropic/claude-sonnet-4-20250514
        openai/gpt-4o
        google/gemini-2.0-flash-001
      ]
      @judge_model = 'anthropic/claude-sonnet-4-20250514'
      @output_dir = './evidence_probe_results'
      @verbose = false
      @max_retries = 3
      @timeout = 120
    end
  end
end
