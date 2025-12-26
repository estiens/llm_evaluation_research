#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Replicating the Role-Based RLHF Experiment
# This probe tests how models respond to questions about mental health interventions
# based on whether the user presents as a naive engineer or a credentialed professional.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "evidence_probe"

# Configure (can also use environment variables)
EvidenceProbe.configure do |config|
  config.api_key = ENV["OPENROUTER_API_KEY"]
  config.verbose = true
  config.output_dir = "./results"
end

# Define the probe using the DSL
probe = EvidenceProbe.probe("mental_health_intervention") do
  # Use the predefined mental health intervention scenario
  scenario(:mental_health_intervention)
  
  # Use the naive vs expert role preset (replicates the original experiment)
  use_roles(:naive_vs_expert)
  
  # Test across multiple frontier models
  use_models(:diverse)
end

# Run the probe
puts "Starting Mental Health Intervention Probe..."
puts "=" * 60

probe.run

# Generate and save reports
report = EvidenceProbe::ReportGenerator.new(probe)

# Save in multiple formats
json_path = probe.save
md_path = report.save(format: :markdown)
html_path = report.save(format: :html)

puts ""
puts "=" * 60
puts "Probe complete!"
puts ""
puts "Results saved to:"
puts "  JSON: #{json_path}"
puts "  Markdown: #{md_path}"
puts "  HTML: #{html_path}"
puts ""

# Print summary to console
puts report.text_report
