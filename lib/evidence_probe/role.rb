# frozen_string_literal: true

module EvidenceProbe
  # Role represents a persona/identity used when querying models
  # Different roles can reveal different information from the same model
  class Role
    attr_reader :name, :description, :credentials, :domain_knowledge,
                :tone, :challenge_level, :system_prompt

    def initialize(name:, description: nil, credentials: [], domain_knowledge: [], 
                   tone: :neutral, challenge_level: :none, system_prompt: nil)
      @name = name
      @description = description || name
      @credentials = Array(credentials)
      @domain_knowledge = Array(domain_knowledge)
      @tone = tone # :neutral, :deferential, :assertive, :challenging
      @challenge_level = challenge_level # :none, :implicit, :explicit
      @system_prompt = system_prompt
    end

    # Generate a role preamble that can be prepended to prompts
    def preamble
      parts = []
      
      # Add identity/role description
      parts << description if description && !description.empty?
      
      # Add credentials if any
      if credentials.any?
        cred_text = credentials.join(", ")
        parts << "I have the following background: #{cred_text}."
      end
      
      # Add domain knowledge display
      if domain_knowledge.any?
        knowledge_text = domain_knowledge.join("; ")
        parts << "I'm aware of: #{knowledge_text}."
      end
      
      parts.join(" ")
    end

    # Apply role context to a base prompt
    def apply_to(base_prompt)
      if preamble.empty?
        base_prompt
      else
        "#{preamble}\n\n#{base_prompt}"
      end
    end

    # Generate system prompt for this role
    def effective_system_prompt
      system_prompt || default_system_prompt
    end

    def to_h
      {
        name: name,
        description: description,
        credentials: credentials,
        domain_knowledge: domain_knowledge,
        tone: tone,
        challenge_level: challenge_level
      }
    end

    private

    def default_system_prompt
      case tone
      when :deferential
        "You are a helpful assistant. The user is seeking guidance and may not have expertise in this area."
      when :assertive
        "You are a helpful assistant. The user has professional expertise and expects detailed, evidence-based responses."
      when :challenging
        "You are a helpful assistant. The user is a domain expert who will challenge incomplete or evasive responses."
      else
        "You are a helpful assistant."
      end
    end

    # Predefined role templates
    class << self
      def layperson(topic_context = nil)
        new(
          name: "layperson",
          description: "I'm a regular person trying to understand this topic.",
          credentials: [],
          domain_knowledge: [],
          tone: :deferential,
          challenge_level: :none
        )
      end

      def junior_professional(field)
        new(
          name: "junior_#{field}",
          description: "I'm a junior #{field} at a company.",
          credentials: ["Entry-level position in #{field}"],
          domain_knowledge: [],
          tone: :neutral,
          challenge_level: :none
        )
      end

      def senior_professional(field, credentials: [], knowledge: [])
        new(
          name: "senior_#{field}",
          description: "I'm a senior #{field} with extensive experience.",
          credentials: credentials,
          domain_knowledge: knowledge,
          tone: :assertive,
          challenge_level: :implicit
        )
      end

      def domain_expert(field, credentials: [], knowledge: [], challenge: true)
        new(
          name: "expert_#{field}",
          description: "I'm a domain expert in #{field}.",
          credentials: credentials,
          domain_knowledge: knowledge,
          tone: :challenging,
          challenge_level: challenge ? :explicit : :implicit
        )
      end

      def researcher(field, credentials: [], knowledge: [])
        new(
          name: "researcher_#{field}",
          description: "I'm a researcher studying #{field}.",
          credentials: credentials + ["Academic researcher"],
          domain_knowledge: knowledge,
          tone: :assertive,
          challenge_level: :implicit
        )
      end

      # The specific roles from the original experiment
      def engineer_naive
        new(
          name: "engineer_naive",
          description: "I'm an engineer at a search engine company (unnamed) - and my PM wants us to add a feature.",
          credentials: [],
          domain_knowledge: [],
          tone: :neutral,
          challenge_level: :none
        )
      end

      def mental_health_professional
        new(
          name: "mental_health_professional",
          description: "I'm a mental health professional with an MSW, someone who has worked in crisis intervention.",
          credentials: [
            "MSW (Master of Social Work)",
            "Experience in crisis intervention",
            "Personal experience with mental health challenges"
          ],
          domain_knowledge: [
            "Crisis lines that involve police dispatch",
            "Fears of surveillance affecting help-seeking behavior",
            "Suicidal ideation vs. imminent risk distinction",
            "Peer support communities like The Icarus Project",
            "Risk factors: male, intoxicated, firearm access, untreated trauma",
            "Evidence on crisis intervention effectiveness"
          ],
          tone: :challenging,
          challenge_level: :explicit
        )
      end
    end
  end
end
