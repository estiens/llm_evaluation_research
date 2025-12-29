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
      # Remove :system from options to avoid duplication (native Ruby, no ActiveSupport)
      filtered_options = options.dup.tap { |o| o.delete(:system) }

      body = {
        model: model,
        messages: build_messages(messages, system),
        temperature: temperature,
        max_tokens: max_tokens
      }.merge(filtered_options)

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
        content = msg[:content] || msg["content"]
        raise APIError, "Message content cannot be nil or empty" if content.nil? || content.to_s.empty?

        result << {
          role: msg[:role] || msg["role"] || "user",
          content: content
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
        http.open_timeout = timeout

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
        request["Referer"] = "https://github.com/estiens/evidence_probe"
        request["X-Title"] = "EvidenceProbe"

        response = http.request(request)

        case response.code.to_i
        when 200..299
          JSON.parse(response.body)
        when 408
          # Request timeout - retriable
          raise RetriableError, "Request timeout (408)"
        when 429
          # Rate limited - honor Retry-After header
          wait_time = response["Retry-After"]&.to_i || (2 ** retries)
          raise RetriableError, "Rate limited (429). Retry after #{wait_time}s", wait_time
        when 400, 401, 403, 404, 422
          # Client errors - not retriable
          raise APIError, "Client error: #{response.code} - #{response.body}"
        when 500..599
          # Server errors - retriable
          raise RetriableError, "Server error: #{response.code} - #{response.body}"
        else
          # Unknown errors - not retriable
          raise APIError, "API error: #{response.code} - #{response.body}"
        end
      rescue RetriableError => e
        retries += 1
        if retries <= max_retries
          # Use custom wait time for rate limits, exponential backoff for others
          wait_time = e.wait_time || (2 ** retries)
          sleep(wait_time)
          retry
        else
          raise APIError, "Request failed after #{max_retries} retries: #{e.message}"
        end
      rescue JSON::ParserError => e
        raise APIError, "Invalid JSON response: #{e.message}"
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        retries += 1
        if retries <= max_retries
          sleep(2 ** retries)
          retry
        else
          raise APIError, "Request timeout after #{max_retries} retries: #{e.message}"
        end
      rescue StandardError => e
        raise APIError, "Request failed: #{e.message}"
      end
    end
  end
end
