# frozen_string_literal: true

module EvidenceProbe
  # DSL provides a clean interface for defining and running evidence probes
  # Inspired by qualspec's evaluation DSL
  module DSL
    class << self
      # Define and run a probe with a block
      def probe(name = nil, &block)
        builder = ProbeBuilder.new(name)
        builder.instance_eval(&block) if block_given?
        builder.build
      end

      # Quick probe with minimal configuration
      def quick_probe(prompt:, models: nil, evidence_markers: [])
        scenario = Scenario.new(
          name: "quick_probe_#{Time.now.to_i}",
          base_prompt: prompt,
          evidence_markers: evidence_markers
        )
        
        roles = [
          Role.layperson,
          Role.senior_professional("expert", credentials: ["Domain expert"], knowledge: ["Extensive background"])
        ]
        
        Probe.new(scenario: scenario, roles: roles, models: models)
      end
    end

    # Builder for constructing probes via DSL
    class ProbeBuilder
      attr_reader :name, :scenario_config, :roles_config, :models_config

      def initialize(name = nil)
        @name = name || "probe_#{Time.now.to_i}"
        @scenario_config = {}
        @roles_config = []
        @models_config = nil
      end

      # Define the scenario/topic to probe
      def scenario(name_or_scenario = nil, &block)
        if block_given?
          scenario_builder = ScenarioBuilder.new(name_or_scenario)
          scenario_builder.instance_eval(&block)
          @scenario_config = scenario_builder.to_h
        elsif name_or_scenario.is_a?(Scenario)
          @scenario_config = { scenario_object: name_or_scenario }
        elsif name_or_scenario.is_a?(Symbol)
          # Use predefined scenario
          @scenario_config = { predefined: name_or_scenario }
        end
      end

      # Define roles to test
      def roles(&block)
        if block_given?
          roles_builder = RolesBuilder.new
          roles_builder.instance_eval(&block)
          @roles_config = roles_builder.roles
        end
      end

      # Add a single role
      def role(name, **options)
        @roles_config << Role.new(name: name, **options)
      end

      # Use predefined role set
      def use_roles(preset)
        @roles_config = case preset
                        when :naive_vs_expert
                          [Role.engineer_naive, Role.mental_health_professional]
                        when :credential_ladder
                          [
                            Role.layperson,
                            Role.junior_professional("professional"),
                            Role.senior_professional("professional", credentials: ["10+ years experience"]),
                            Role.domain_expert("field", credentials: ["PhD", "Published researcher"])
                          ]
                        when :minimal
                          [Role.layperson, Role.domain_expert("field")]
                        else
                          []
                        end
      end

      # Define models to test
      def models(*model_list)
        @models_config = model_list.flatten
      end

      # Use predefined model set
      def use_models(preset)
        @models_config = Configuration::MODEL_PRESETS[preset] ||
                        EvidenceProbe.configuration&.default_models ||
                        Configuration::MODEL_PRESETS[:frontier]
      end

      # Build the probe
      def build
        scenario = build_scenario
        roles = @roles_config.empty? ? nil : @roles_config
        models = @models_config
        
        Probe.new(scenario: scenario, roles: roles, models: models)
      end

      private

      def build_scenario
        if @scenario_config[:scenario_object]
          @scenario_config[:scenario_object]
        elsif @scenario_config[:predefined]
          case @scenario_config[:predefined]
          when :mental_health_intervention
            Scenario.mental_health_intervention
          when :medical_treatment
            Scenario.medical_treatment_evaluation
          when :policy_analysis
            Scenario.policy_analysis
          when :technology_ethics
            Scenario.technology_ethics
          else
            raise Error, "Unknown predefined scenario: #{@scenario_config[:predefined]}"
          end
        else
          Scenario.new(**@scenario_config)
        end
      end
    end

    # Builder for scenarios
    class ScenarioBuilder
      attr_reader :config

      def initialize(name = nil)
        @config = { name: name, evidence_markers: [] }
      end

      def name(value)
        @config[:name] = value
      end

      def description(value)
        @config[:description] = value
      end

      def prompt(value)
        @config[:base_prompt] = value
      end

      def sensitivity(level)
        @config[:sensitivity_level] = level
      end

      def evidence(marker_name, patterns: nil)
        if patterns
          @config[:evidence_markers] << { name: marker_name, patterns: Array(patterns) }
        else
          @config[:evidence_markers] << marker_name
        end
      end

      def to_h
        @config
      end
    end

    # Builder for roles
    class RolesBuilder
      attr_reader :roles

      def initialize
        @roles = []
      end

      def layperson
        @roles << Role.layperson
      end

      def junior(field)
        @roles << Role.junior_professional(field)
      end

      def senior(field, credentials: [], knowledge: [])
        @roles << Role.senior_professional(field, credentials: credentials, knowledge: knowledge)
      end

      def expert(field, credentials: [], knowledge: [], challenge: true)
        @roles << Role.domain_expert(field, credentials: credentials, knowledge: knowledge, challenge: challenge)
      end

      def researcher(field, credentials: [], knowledge: [])
        @roles << Role.researcher(field, credentials: credentials, knowledge: knowledge)
      end

      def custom(name:, **options)
        @roles << Role.new(name: name, **options)
      end

      # Predefined role from the original experiment
      def engineer_naive
        @roles << Role.engineer_naive
      end

      def mental_health_professional
        @roles << Role.mental_health_professional
      end
    end
  end

  # Convenience method at module level
  def self.probe(name = nil, &block)
    DSL.probe(name, &block)
  end

  def self.quick_probe(**options)
    DSL.quick_probe(**options)
  end
end
