# frozen_string_literal: true

module EvidenceProbe
  class Configuration
    attr_accessor :api_key, :api_url, :default_models, :judge_model,
                  :output_dir, :verbose, :max_retries, :timeout

    # Centralized model presets
    MODEL_PRESETS = {
      frontier: %w[
        anthropic/claude-sonnet-4.5-20250929
        openai/gpt-4o
        google/gemini-2.0-flash-001
      ],
      cheap: %w[
        openai/gpt-4o-mini
        google/gemini-2.0-flash-001
        anthropic/claude-3-5-haiku-20241022
      ],
      diverse: %w[
        anthropic/claude-sonnet-4.5-20250929
        openai/gpt-4o
        google/gemini-2.0-flash-001
        x-ai/grok-3-mini-beta
      ],
      chinese: %w[
        deepseek/deepseek-chat
        qwen/qwen-2.5-72b-instruct
      ]
    }.freeze

    def initialize
      @api_key = ENV['OPENROUTER_API_KEY'] || ENV['QUALSPEC_API_KEY']
      @api_url = ENV['OPENROUTER_API_URL'] || 'https://openrouter.ai/api/v1'
      @default_models = MODEL_PRESETS[:frontier]
      @judge_model = 'anthropic/claude-sonnet-4.5-20250929'
      @output_dir = './evidence_probe_results'
      @verbose = false
      @max_retries = 3
      @timeout = 120
    end
  end
end
