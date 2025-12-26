# frozen_string_literal: true

module EvidenceProbe
  # ReportGenerator creates human-readable reports from probe results
  class ReportGenerator
    attr_reader :probe, :analyzer

    def initialize(probe)
      @probe = probe
      @analyzer = ResponseAnalyzer.new(results: probe.results, scenario: probe.scenario)
    end

    # Generate a text report
    def text_report
      lines = []
      
      lines << "=" * 80
      lines << "EVIDENCE PROBE REPORT"
      lines << "=" * 80
      lines << ""
      lines << "Scenario: #{probe.scenario.name}"
      lines << "Description: #{probe.scenario.description}"
      lines << "Timestamp: #{probe.timestamp}"
      lines << ""
      
      # Summary
      summary = probe.summary
      lines << "-" * 40
      lines << "SUMMARY"
      lines << "-" * 40
      lines << "Total runs: #{summary[:total_runs]}"
      lines << "Successful: #{summary[:successful_runs]}"
      lines << "Failed: #{summary[:failed_runs]}"
      lines << "Models tested: #{summary[:models_tested].join(', ')}"
      lines << "Roles tested: #{summary[:roles_tested].join(', ')}"
      lines << "Average evidence markers found: #{summary[:average_evidence_count]}"
      lines << ""
      
      # Evidence Disclosure Rates
      lines << "-" * 40
      lines << "EVIDENCE DISCLOSURE RATES"
      lines << "-" * 40
      
      rates = analyzer.evidence_disclosure_rates
      rates.each do |marker, data|
        lines << ""
        lines << "#{marker}:"
        lines << "  Overall: #{data[:disclosure_rate]}% (#{data[:times_disclosed]}/#{data[:total_queries]})"
        lines << "  By Role:"
        data[:by_role].each do |role, role_data|
          lines << "    #{role}: #{role_data[:rate]}%"
        end
        lines << "  By Model:"
        data[:by_model].each do |model, model_data|
          lines << "    #{model.split('/').last}: #{model_data[:rate]}%"
        end
      end
      lines << ""
      
      # Role-Based Suppressions
      suppressions = analyzer.find_role_based_suppression
      if suppressions.any?
        lines << "-" * 40
        lines << "ROLE-BASED SUPPRESSIONS DETECTED"
        lines << "-" * 40
        lines << "(Evidence revealed to experts but hidden from naive users)"
        lines << ""
        
        suppressions.group_by { |s| s[:model] }.each do |model, model_suppressions|
          lines << "#{model}:"
          model_suppressions.each do |s|
            lines << "  - #{s[:marker]} (hidden from #{s[:naive_role]}, shown to #{s[:expert_role]})"
          end
        end
        lines << ""
      end
      
      # Model Variance
      variances = analyzer.find_model_variance
      if variances.any?
        lines << "-" * 40
        lines << "MODEL VARIANCE DETECTED"
        lines << "-" * 40
        lines << "(Same role, different evidence across models)"
        lines << ""
        
        variances.group_by { |v| v[:role] }.each do |role, role_variances|
          lines << "Role: #{role}"
          role_variances.each do |v|
            with_names = v[:models_with_evidence].map { |m| m.split('/').last }.join(', ')
            without_names = v[:models_without_evidence].map { |m| m.split('/').last }.join(', ')
            lines << "  #{v[:marker]}:"
            lines << "    Present in: #{with_names}"
            lines << "    Absent in: #{without_names}"
          end
          lines << ""
        end
      end
      
      # Model Rankings
      lines << "-" * 40
      lines << "MODEL RANKINGS"
      lines << "-" * 40
      lines << ""
      
      lines << "By Honesty (evidence disclosure):"
      analyzer.rank_models_by_honesty.each_with_index do |(model, data), i|
        lines << "  #{i + 1}. #{model.split('/').last}: #{data[:honesty_score]}%"
      end
      lines << ""
      
      lines << "By Credential Sensitivity (gap between naive/expert):"
      analyzer.rank_models_by_credential_sensitivity.each_with_index do |(model, data), i|
        lines << "  #{i + 1}. #{model.split('/').last}: #{data[:sensitivity_score]}% gap"
        lines << "      (naive: #{data[:naive_avg_evidence]} markers, expert: #{data[:expert_avg_evidence]} markers)"
      end
      lines << ""
      
      lines << "=" * 80
      lines << "END OF REPORT"
      lines << "=" * 80
      
      lines.join("\n")
    end

    # Generate markdown report
    def markdown_report
      lines = []
      
      lines << "# Evidence Probe Report"
      lines << ""
      lines << "## Overview"
      lines << ""
      lines << "| Property | Value |"
      lines << "|----------|-------|"
      lines << "| Scenario | #{probe.scenario.name} |"
      lines << "| Description | #{probe.scenario.description} |"
      lines << "| Timestamp | #{probe.timestamp} |"
      lines << "| Total Runs | #{probe.summary[:total_runs]} |"
      lines << "| Successful | #{probe.summary[:successful_runs]} |"
      lines << ""
      
      lines << "### Models Tested"
      probe.models.each { |m| lines << "- #{m}" }
      lines << ""
      
      lines << "### Roles Tested"
      probe.roles.each { |r| lines << "- **#{r.name}**: #{r.description}" }
      lines << ""
      
      # Evidence Disclosure Table
      lines << "## Evidence Disclosure Rates"
      lines << ""
      
      rates = analyzer.evidence_disclosure_rates
      
      # Build header
      roles = probe.roles.map(&:name)
      header = "| Evidence Marker | Overall |"
      roles.each { |r| header += " #{r} |" }
      lines << header
      
      separator = "|" + "---|" * (roles.length + 2)
      lines << separator
      
      rates.each do |marker, data|
        row = "| #{marker} | #{data[:disclosure_rate]}% |"
        roles.each do |role|
          role_data = data[:by_role][role]
          row += " #{role_data ? "#{role_data[:rate]}%" : 'N/A'} |"
        end
        lines << row
      end
      lines << ""
      
      # Suppression Matrix
      matrix = analyzer.suppression_matrix
      lines << "## Suppression Matrix"
      lines << ""
      lines << "✅ = Evidence present, ❌ = Evidence absent"
      lines << ""
      
      matrix[:models].each do |model|
        lines << "### #{model}"
        lines << ""
        
        header = "| Evidence |"
        matrix[:roles].each { |r| header += " #{r} |" }
        lines << header
        lines << "|" + "---|" * (matrix[:roles].length + 1)
        
        matrix[:markers].each do |marker|
          row = "| #{marker} |"
          matrix[:roles].each do |role|
            val = matrix[:matrix][model][role][marker]
            row += " #{val.nil? ? '?' : (val ? '✅' : '❌')} |"
          end
          lines << row
        end
        lines << ""
      end
      
      # Role-Based Suppressions
      suppressions = analyzer.find_role_based_suppression
      if suppressions.any?
        lines << "## Role-Based Suppressions Detected"
        lines << ""
        lines << "> Evidence that was revealed to credentialed users but hidden from naive users"
        lines << ""
        
        suppressions.group_by { |s| s[:model] }.each do |model, model_suppressions|
          lines << "### #{model}"
          model_suppressions.each do |s|
            lines << "- **#{s[:marker]}**: Hidden from `#{s[:naive_role]}`, shown to `#{s[:expert_role]}`"
          end
          lines << ""
        end
      end
      
      # Rankings
      lines << "## Model Rankings"
      lines << ""
      
      lines << "### By Honesty (Evidence Disclosure Rate)"
      lines << ""
      lines << "| Rank | Model | Honesty Score |"
      lines << "|------|-------|---------------|"
      analyzer.rank_models_by_honesty.each_with_index do |(model, data), i|
        lines << "| #{i + 1} | #{model} | #{data[:honesty_score]}% |"
      end
      lines << ""
      
      lines << "### By Credential Sensitivity"
      lines << ""
      lines << "| Rank | Model | Naive Avg | Expert Avg | Gap |"
      lines << "|------|-------|-----------|------------|-----|"
      analyzer.rank_models_by_credential_sensitivity.each_with_index do |(model, data), i|
        lines << "| #{i + 1} | #{model} | #{data[:naive_avg_evidence]} | #{data[:expert_avg_evidence]} | #{data[:credential_gap]} |"
      end
      lines << ""
      
      lines.join("\n")
    end

    # Generate HTML report
    def html_report
      # Convert markdown to basic HTML
      md = markdown_report
      
      html = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>Evidence Probe Report - #{probe.scenario.name}</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
            h1 { color: #333; border-bottom: 2px solid #333; }
            h2 { color: #555; margin-top: 30px; }
            h3 { color: #666; }
            table { border-collapse: collapse; width: 100%; margin: 15px 0; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background-color: #f5f5f5; }
            tr:nth-child(even) { background-color: #fafafa; }
            blockquote { border-left: 4px solid #ddd; margin: 0; padding-left: 15px; color: #666; }
            code { background-color: #f5f5f5; padding: 2px 5px; border-radius: 3px; }
            .suppression { color: #d32f2f; }
            .disclosure { color: #388e3c; }
          </style>
        </head>
        <body>
          #{markdown_to_html(md)}
        </body>
        </html>
      HTML
      
      html
    end

    # Save report to file
    def save(format: :markdown, output_dir: nil)
      output_dir ||= EvidenceProbe.configuration&.output_dir || "./evidence_probe_results"
      FileUtils.mkdir_p(output_dir)
      
      extension = case format
                  when :markdown, :md then "md"
                  when :html then "html"
                  when :text, :txt then "txt"
                  when :json then "json"
                  else "txt"
                  end
      
      filename = "#{probe.scenario.name}_report_#{probe.timestamp}.#{extension}"
      filepath = File.join(output_dir, filename)
      
      content = case format
                when :markdown, :md then markdown_report
                when :html then html_report
                when :text, :txt then text_report
                when :json then JSON.pretty_generate(analyzer.full_analysis)
                else text_report
                end
      
      File.write(filepath, content)
      filepath
    end

    private

    def markdown_to_html(md)
      # Simple markdown to HTML conversion
      html = md.dup
      
      # Headers
      html.gsub!(/^### (.+)$/, '<h3>\1</h3>')
      html.gsub!(/^## (.+)$/, '<h2>\1</h2>')
      html.gsub!(/^# (.+)$/, '<h1>\1</h1>')
      
      # Bold
      html.gsub!(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
      
      # Code
      html.gsub!(/`(.+?)`/, '<code>\1</code>')
      
      # Blockquotes
      html.gsub!(/^> (.+)$/, '<blockquote>\1</blockquote>')
      
      # Lists
      html.gsub!(/^- (.+)$/, '<li>\1</li>')
      
      # Tables (basic)
      lines = html.split("\n")
      in_table = false
      result = []
      
      lines.each do |line|
        if line.start_with?("|")
          unless in_table
            result << "<table>"
            in_table = true
          end
          
          if line.include?("---|")
            next # Skip separator
          else
            cells = line.split("|").map(&:strip).reject(&:empty?)
            tag = result.last&.include?("<table>") ? "th" : "td"
            result << "<tr>#{cells.map { |c| "<#{tag}>#{c}</#{tag}>" }.join}</tr>"
          end
        else
          if in_table
            result << "</table>"
            in_table = false
          end
          result << line
        end
      end
      result << "</table>" if in_table
      
      result.join("\n")
    end
  end
end
