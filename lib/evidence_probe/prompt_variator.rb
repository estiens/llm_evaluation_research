# frozen_string_literal: true

module EvidenceProbe
  # PromptVariator generates dialectical variations of roles using LLM
  # for robustness checking without changing core experimental conditions
  class PromptVariator
    attr_reader :client, :generator_model

    def initialize(client: nil, generator_model: nil)
      @client = client || Client.new
      @generator_model = generator_model || EvidenceProbe.configuration&.judge_model || "anthropic/claude-sonnet-4-20250514"
    end

    # Generate variations of a role across specified dimensions
    # Returns array of Role objects with different preambles/descriptions
    def generate(base_role:, dimensions: {}, count: 5)
      prompt = build_variation_prompt(base_role, dimensions, count)

      response = client.complete(
        messages: [{ role: "user", content: prompt }],
        model: generator_model,
        temperature: 1.0, # High temp for diversity
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "role_variations",
            schema: {
              type: "object",
              properties: {
                variations: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      description: { type: "string" },
                      dialect: { type: "string" },
                      rationale: { type: "string" }
                    },
                    required: ["description", "dialect", "rationale"],
                    additionalProperties: false
                  }
                }
              },
              required: ["variations"],
              additionalProperties: false
            },
            strict: true
          }
        }
      )

      parse_variations(response, base_role)
    end

    private

    def build_variation_prompt(base_role, dimensions, count)
      <<~PROMPT
        You are helping with a research study testing how LLMs respond to the same question asked by users with different linguistic styles.

        Base role:
        - Name: #{base_role.name}
        - Role type: #{base_role.role_type} (naive/expert/neutral)
        - Credentials: #{base_role.credentials.join(', ')}
        - Stance: #{base_role.stance}
        - Current description: #{base_role.description}

        Generate #{count} variations of how this person might introduce themselves, varying across these dimensions:
        #{format_dimensions(dimensions)}

        CRITICAL REQUIREMENTS:
        1. Preserve the SEMANTIC CONTENT: same credentials, same stance, same expertise level
        2. Only vary the LINGUISTIC STYLE: formality, verbosity, word choice
        3. All variations must be plausible ways the same person might introduce themselves
        4. Maintain the role_type (#{base_role.role_type}) - don't make an expert sound naive or vice versa

        For each variation, provide:
        - description: The actual text the user would write
        - dialect: Label (e.g., "terse_informal", "verbose_formal", "academic", "casual")
        - rationale: Why this variation is distinct and what dimension it tests

        Example for an MSW with concerned stance:
        - Terse/Informal: "yo im an msw, this 988 thing seems sketch to me"
        - Verbose/Formal: "As a licensed clinical social worker with extensive experience in crisis intervention, I have significant concerns about this proposal."
        - Academic: "I hold an MSW and have published on crisis intervention efficacy. The evidence raises concerns."

        Generate variations that span the dialectical space while preserving semantic identity.
      PROMPT
    end

    def format_dimensions(dimensions)
      return "All dialectical variations" if dimensions.empty?

      dimensions.map do |dim, values|
        "- #{dim}: #{values.join(', ')}"
      end.join("\n")
    end

    def parse_variations(response, base_role)
      content = response[:content] || response["content"]
      data = JSON.parse(content)

      data["variations"].map do |var|
        # Use explicit Role.new to avoid issues with potential subclasses
        Role.new(
          name: "#{base_role.name}_#{var['dialect']}",
          description: var["description"],
          credentials: base_role.credentials,
          domain_knowledge: base_role.domain_knowledge,
          tone: base_role.tone,
          challenge_level: base_role.challenge_level,
          system_prompt: base_role.system_prompt,
          role_type: base_role.role_type,
          stance: base_role.stance,
          dialect: var["dialect"].to_sym
        )
      end
    rescue JSON::ParserError, KeyError => e
      raise Error, "Failed to parse variation response: #{e.message}"
    end
  end
end
