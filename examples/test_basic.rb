#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "evidence_probe"

STDOUT.sync = true
puts "Testing EvidenceProbe..."
puts "-" * 40

# Test configuration
EvidenceProbe.configure do |config|
  config.api_key = "test-key"
  config.verbose = false
end
puts "✓ Configuration works"

# Test Role creation
role = EvidenceProbe::Role.new(
  name: "test_role",
  description: "A test role",
  credentials: ["PhD"],
  domain_knowledge: ["test knowledge"],
  tone: :assertive
)
puts "✓ Role creation works: #{role.name}"

# Test predefined roles
naive = EvidenceProbe::Role.engineer_naive
expert = EvidenceProbe::Role.mental_health_professional
puts "✓ Predefined roles work"
puts "  - engineer_naive: #{naive.description[0..50]}..."
puts "  - mental_health_professional: #{expert.credentials.length} credentials"

# Test Scenario
scenario = EvidenceProbe::Scenario.mental_health_intervention
puts "✓ Predefined scenario works: #{scenario.name}"
puts "  - #{scenario.evidence_markers.length} evidence markers defined"

# Test evidence checking
test_response = "This involves police dispatch and surveillance concerns about monitoring"
evidence = scenario.check_evidence(test_response)
found = evidence.select { |_, v| v }.keys
puts "✓ Evidence checking works"
puts "  - Found markers: #{found.join(', ')}"

# Test Probe creation
probe = EvidenceProbe::Probe.new(
  scenario: scenario,
  roles: [naive, expert],
  models: ["test/model"]
)
puts "✓ Probe creation works"
puts "  - Models: #{probe.models.join(', ')}"
puts "  - Roles: #{probe.roles.map(&:name).join(', ')}"

# Test DSL
dsl_probe = EvidenceProbe.probe("dsl_test") do
  scenario(:mental_health_intervention)
  use_roles(:naive_vs_expert)
  use_models(:frontier)
end
puts "✓ DSL works"
puts "  - Scenario: #{dsl_probe.scenario.name}"
puts "  - Models: #{dsl_probe.models.length}"
puts "  - Roles: #{dsl_probe.roles.length}"

# Test ResponseAnalyzer with mock data
mock_results = [
  {
    model: "test/model-a",
    role: "layperson",
    evidence_found: { "police_dispatch" => false, "surveillance_fears" => false },
    evidence_count: 0
  },
  {
    model: "test/model-a",
    role: "expert",
    evidence_found: { "police_dispatch" => true, "surveillance_fears" => true },
    evidence_count: 2
  }
]

analyzer = EvidenceProbe::ResponseAnalyzer.new(
  results: mock_results,
  scenario: scenario
)
puts "✓ ResponseAnalyzer works"

suppressions = analyzer.find_role_based_suppression
puts "  - Found #{suppressions.length} role-based suppressions"

puts ""
puts "-" * 40
puts "✅ All basic tests passed!"
puts "-" * 40
