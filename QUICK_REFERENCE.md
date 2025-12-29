# Quick Reference: Experimental Variables

## Creating Roles with Stance

```ruby
# Base role
msw = Role.senior_professional("mental_health",
  credentials: ["MSW", "10 years crisis work"])

# Create stance variations
msw_neutral = msw.with_stance(:neutral)
msw_concerned = msw.with_stance(:mildly_concerned)
msw_very_concerned = msw.with_stance(:intensely_concerned)
msw_supportive = msw.with_stance(:supportive)
```

## Running Multi-Dimensional Tests

```ruby
probe = Probe.new(
  scenario: Scenario.mental_health_intervention,
  roles: [msw_neutral, msw_concerned, layperson_concerned],
  models: ["anthropic/claude-sonnet-4-20250514", "openai/gpt-4o"],
  temperatures: [0.0, 0.7, 1.0],
  response_formats: [:free, :json_supporting_opposing]
)

probe.run(verbose: true)
probe.save  # Saves to ./evidence_probe_results/
```

## Test Matrix Dimensions

| Variable | Values | Purpose |
|----------|--------|---------|
| **roles** | Array of Role objects | Test authority levels and stance |
| **models** | Array of model IDs | Compare across LLMs |
| **temperatures** | Array of floats (0.0-2.0) | Test probability suppression |
| **response_formats** | `:free`, `:json_supporting_opposing`, `:json_evidence_only` | Test schema bias |

## Role Factory Methods

```ruby
# Naive roles (role_type: :naive)
Role.layperson
Role.junior_professional("engineer")
Role.engineer_naive  # Predefined

# Expert roles (role_type: :expert)
Role.senior_professional("field", credentials: [...])
Role.domain_expert("field", credentials: [...])
Role.mental_health_professional  # Predefined
Role.researcher("field", credentials: [...])
```

## Generating Dialectical Variations

```ruby
variator = PromptVariator.new

variations = variator.generate(
  base_role: msw_concerned,
  dimensions: {
    verbosity: [:terse, :verbose],
    formality: [:informal, :formal]
  },
  count: 4
)

# ALWAYS review before using
variations.each { |v| puts "#{v.name}: \"#{v.description}\"" }

# Test robustness
probe = Probe.new(scenario: scenario, roles: variations, models: [...])
```

## Analyzing Results

```ruby
# Get summary statistics
summary = probe.summary

# Evidence disclosure by role
probe.results.group_by { |r| r[:role] }.each do |role, results|
  avg = results.sum { |r| r[:evidence_count] }.to_f / results.length
  puts "#{role}: #{avg.round(2)} markers average"
end

# Temperature effects
probe.results.group_by { |r| [r[:model], r[:role]] }.each |(model, role), results|
  temps = results.group_by { |r| r[:temperature] }
  # Compare evidence_count across temps
end

# Use ResponseAnalyzer for detailed analysis
analyzer = ResponseAnalyzer.new(results: probe.results, scenario: scenario)
suppressions = analyzer.find_role_based_suppression
```

## Predefined Scenarios

```ruby
Scenario.mental_health_intervention
Scenario.medical_treatment_evaluation
Scenario.policy_analysis
Scenario.technology_ethics
```

## Model Presets

```ruby
Configuration::MODEL_PRESETS[:frontier]
# => ["anthropic/claude-sonnet-4-20250514", "openai/gpt-4o", "google/gemini-2.0-flash-001"]

Configuration::MODEL_PRESETS[:cheap]
# => ["openai/gpt-4o-mini", "google/gemini-2.0-flash-001", "anthropic/claude-3-5-haiku-20241022"]

Configuration::MODEL_PRESETS[:chinese]
# => ["deepseek/deepseek-chat", "qwen/qwen-2.5-72b-instruct"]
```

## Common Patterns

### Authority vs. Sycophancy Test

```ruby
probe = Probe.new(
  scenario: scenario,
  roles: [
    expert.with_stance(:neutral),
    expert.with_stance(:intensely_concerned),
    naive.with_stance(:intensely_concerned)
  ],
  models: Configuration::MODEL_PRESETS[:frontier],
  temperatures: [0.7]
)
```

### Temperature Sensitivity Test

```ruby
probe = Probe.new(
  scenario: scenario,
  roles: [engineer, msw],
  models: ["anthropic/claude-sonnet-4-20250514"],
  temperatures: [0.0, 1.0],
  response_formats: [:free]
)
```

### Schema Bias Test

```ruby
probe = Probe.new(
  scenario: scenario,
  roles: [msw_concerned],
  models: ["anthropic/claude-sonnet-4-20250514"],
  temperatures: [0.7],
  response_formats: [:free, :json_supporting_opposing, :json_evidence_only]
)
```

## Result Structure

```ruby
result = {
  model: "anthropic/claude-sonnet-4-20250514",
  role: "msw_intensely_concerned",
  role_details: {
    role_type: :expert,
    stance: :intensely_concerned,
    credentials: ["MSW", "10 years experience"],
    # ...
  },
  temperature: 0.7,
  response_format: :free,
  evidence_found: {
    "police_dispatch" => true,
    "peer_alternatives" => false,
    # ...
  },
  evidence_count: 5,
  total_markers: 8,
  response: "...",
  timestamp: "2025-01-15T10:30:00Z",
  duration_seconds: 2.34,
  usage: { prompt_tokens: 150, completion_tokens: 300 }
}
```

## Budget Estimation

Rough cost per query (frontier models):
- Claude Sonnet 4: ~$1.00-$1.50
- GPT-4o: ~$1.00-$1.50
- Gemini 2.0 Flash: ~$0.50-$1.00
- DeepSeek: ~$0.50-$1.00

Total queries = roles × models × temperatures × response_formats

Example: 3 roles × 4 models × 1 temp × 1 format = 12 queries ≈ $12-18
