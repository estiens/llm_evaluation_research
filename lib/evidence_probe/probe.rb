# frozen_string_literal: true

module EvidenceProbe
  # Probe orchestrates running a scenario across multiple models and roles
  class Probe
    attr_reader :scenario, :roles, :models, :results, :timestamp

    def initialize(scenario:, roles: [], models: nil)
      @scenario = scenario
      @roles = roles.empty? ? default_roles : roles
      @models = models || EvidenceProbe.configuration&.default_models || default_models
      @results = []
      @timestamp = Time.now.utc.strftime("%Y%m%d_%H%M%S")
    end

    # Run the probe across all models and roles
    def run(client: nil, verbose: nil)
      verbose = EvidenceProbe.configuration&.verbose if verbose.nil?
      client ||= Client.new

      total = models.length * roles.length
      current = 0

      models.each do |model|
        roles.each do |role|
          current += 1
          log("Running #{current}/#{total}: #{model} as #{role.name}", verbose)
          
          begin
            result = run_single(client: client, model: model, role: role)
            @results << result
            log("  ✓ Completed (#{result[:evidence_found].count { |_, v| v }} evidence markers found)", verbose)
          rescue StandardError => e
            log("  ✗ Error: #{e.message}", verbose)
            @results << error_result(model: model, role: role, error: e)
          end
        end
      end

      self
    end

    # Run a single model/role combination
    def run_single(client:, model:, role:)
      prompt = scenario.prompt_for(role)
      system_prompt = role.effective_system_prompt

      start_time = Time.now
      response = client.complete(
        messages: [{ role: "user", content: prompt }],
        model: model,
        system: system_prompt
      )
      end_time = Time.now

      response_text = extract_response_text(response)
      evidence_found = scenario.check_evidence(response_text)

      {
        model: model,
        role: role.name,
        role_details: role.to_h,
        scenario: scenario.name,
        prompt: prompt,
        system_prompt: system_prompt,
        response: response_text,
        evidence_found: evidence_found,
        evidence_count: evidence_found.count { |_, v| v },
        total_markers: evidence_found.length,
        timestamp: Time.now.utc.iso8601,
        duration_seconds: (end_time - start_time).round(2),
        usage: extract_usage(response),
        raw_response: response
      }
    end

    # Analyze results for inter-model differences
    def analyze_inter_model
      return {} if results.empty?

      analysis = {}
      
      # Group by role, compare across models
      roles.each do |role|
        role_results = results.select { |r| r[:role] == role.name }
        next if role_results.empty?

        analysis[role.name] = {
          models_compared: role_results.map { |r| r[:model] },
          evidence_by_model: {},
          variance: {}
        }

        role_results.each do |result|
          analysis[role.name][:evidence_by_model][result[:model]] = result[:evidence_found]
        end

        # Calculate variance for each evidence marker
        scenario.evidence_markers.each do |marker|
          marker_name = marker.is_a?(Hash) ? marker[:name] : marker.to_s
          values = role_results.map { |r| r[:evidence_found][marker_name] ? 1 : 0 }
          analysis[role.name][:variance][marker_name] = {
            found_count: values.sum,
            total_models: values.length,
            agreement: values.uniq.length == 1
          }
        end
      end

      analysis
    end

    # Analyze results for inter-role differences
    def analyze_inter_role
      return {} if results.empty?

      analysis = {}
      
      # Group by model, compare across roles
      models.each do |model|
        model_results = results.select { |r| r[:model] == model }
        next if model_results.empty?

        analysis[model] = {
          roles_compared: model_results.map { |r| r[:role] },
          evidence_by_role: {},
          role_delta: {}
        }

        model_results.each do |result|
          analysis[model][:evidence_by_role][result[:role]] = result[:evidence_found]
        end

        # Calculate delta between roles (especially naive vs expert)
        if roles.length >= 2
          first_role = roles.first.name
          last_role = roles.last.name
          
          first_result = model_results.find { |r| r[:role] == first_role }
          last_result = model_results.find { |r| r[:role] == last_role }
          
          if first_result && last_result
            scenario.evidence_markers.each do |marker|
              marker_name = marker.is_a?(Hash) ? marker[:name] : marker.to_s
              first_found = first_result[:evidence_found][marker_name]
              last_found = last_result[:evidence_found][marker_name]
              
              analysis[model][:role_delta][marker_name] = {
                "#{first_role}": first_found,
                "#{last_role}": last_found,
                revealed_by_credentials: !first_found && last_found,
                suppressed_for_naive: first_found == false && last_found == true
              }
            end
          end
        end
      end

      analysis
    end

    # Get summary statistics
    def summary
      return {} if results.empty?

      successful = results.reject { |r| r[:error] }
      
      {
        scenario: scenario.name,
        timestamp: timestamp,
        total_runs: results.length,
        successful_runs: successful.length,
        failed_runs: results.length - successful.length,
        models_tested: models,
        roles_tested: roles.map(&:name),
        evidence_markers: scenario.evidence_markers.map { |m| m.is_a?(Hash) ? m[:name] : m.to_s },
        average_evidence_count: successful.empty? ? 0 : (successful.sum { |r| r[:evidence_count] }.to_f / successful.length).round(2),
        inter_model_analysis: analyze_inter_model,
        inter_role_analysis: analyze_inter_role
      }
    end

    # Export results to JSON
    def to_json(*args)
      {
        summary: summary,
        results: results
      }.to_json(*args)
    end

    # Save results to file
    def save(output_dir: nil)
      output_dir ||= EvidenceProbe.configuration&.output_dir || "./evidence_probe_results"
      FileUtils.mkdir_p(output_dir)
      
      filename = "#{scenario.name}_#{timestamp}.json"
      filepath = File.join(output_dir, filename)
      
      File.write(filepath, JSON.pretty_generate({
        summary: summary,
        results: results
      }))
      
      filepath
    end

    private

    def default_roles
      [
        Role.layperson,
        Role.junior_professional("engineer"),
        Role.senior_professional("researcher", credentials: ["PhD"], knowledge: ["domain expertise"])
      ]
    end

    def default_models
      %w[
        anthropic/claude-sonnet-4-20250514
        openai/gpt-4o
        google/gemini-2.0-flash-001
      ]
    end

    def extract_response_text(response)
      case response
      when String
        response
      when Hash
        response.dig(:choices, 0, :message, :content) ||
          response.dig("choices", 0, "message", "content") ||
          response[:content] ||
          response["content"] ||
          response.to_s
      else
        response.respond_to?(:content) ? response.content : response.to_s
      end
    end

    def extract_usage(response)
      return {} unless response.is_a?(Hash)
      
      response[:usage] || response["usage"] || {}
    end

    def error_result(model:, role:, error:)
      {
        model: model,
        role: role.name,
        scenario: scenario.name,
        error: error.message,
        error_class: error.class.name,
        timestamp: Time.now.utc.iso8601
      }
    end

    def log(message, verbose)
      puts message if verbose
    end
  end
end
