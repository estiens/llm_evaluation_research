# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module EvidenceProbe
  # Client handles API communication with OpenRouter
  # Designed to work standalone or integrate with open_router_enhanced
  class Client
    attr_reader :api_key, :api_url, :timeout, :max_retries

    def initialize(api_key: nil, api_url: nil, timeout: nil, max_retries: nil)
      config = EvidenceProbe.configuration || EvidenceProbe.configure
      
      @api_key = api_key || config.api_key
      @api_url = api_url || config.api_url
      @timeout = timeout || config.timeout
      @max_retries = max_retries || config.max_retries

      raise ConfigurationError, "API key is required" if @api_key.nil? || @api_key.empty?
    end

    # Make a completion request
    def complete(messages:, model:, system: nil, temperature: 0.7, max_tokens: 4096, **options)
      body = {
        model: model,
        messages: build_messages(messages, system),
        temperature: temperature,
        max_tokens: max_tokens
      }.merge(options.except(:system))

      response = post("/chat/completions", body)
      
      # Extract the response content
      if response["choices"] && response["choices"][0]
        content = response.dig("choices", 0, "message", "content")
        {
          content: content,
          model: response["model"],
          usage: response["usage"],
          raw: response
        }
      else
        raise APIError, "Unexpected response format: #{response}"
      end
    end

    # List available models
    def models
      get("/models")
    end

    private

    def build_messages(messages, system)
      result = []
      
      # Add system message if provided
      if system && !system.empty?
        result << { role: "system", content: system }
      end
      
      # Add user messages
      messages.each do |msg|
        result << {
          role: msg[:role] || msg["role"] || "user",
          content: msg[:content] || msg["content"]
        }
      end
      
      result
    end

    def post(endpoint, body)
      request(:post, endpoint, body)
    end

    def get(endpoint)
      request(:get, endpoint)
    end

    def request(method, endpoint, body = nil)
      uri = URI.parse("#{api_url}#{endpoint}")
      
      retries = 0
      begin
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.read_timeout = timeout
        http.open_timeout = 30

        request = case method
                  when :post
                    req = Net::HTTP::Post.new(uri.request_uri)
                    req.body = body.to_json
                    req
                  when :get
                    Net::HTTP::Get.new(uri.request_uri)
                  end

        request["Authorization"] = "Bearer #{api_key}"
        request["Content-Type"] = "application/json"
        request["HTTP-Referer"] = "https://github.com/estiens/evidence_probe"
        request["X-Title"] = "EvidenceProbe"

        response = http.request(request)
        
        case response.code.to_i
        when 200..299
          JSON.parse(response.body)
        when 429
          # Rate limited - wait and retry
          wait_time = response["Retry-After"]&.to_i || (2 ** retries)
          raise APIError, "Rate limited. Retry after #{wait_time}s"
        when 500..599
          raise APIError, "Server error: #{response.code} - #{response.body}"
        else
          raise APIError, "API error: #{response.code} - #{response.body}"
        end
      rescue APIError => e
        retries += 1
        if retries <= max_retries
          sleep(2 ** retries)
          retry
        else
          raise
        end
      rescue StandardError => e
        retries += 1
        if retries <= max_retries
          sleep(2 ** retries)
          retry
        else
          raise APIError, "Request failed after #{max_retries} retries: #{e.message}"
        end
      end
    end
  end
end
