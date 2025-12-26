# EvidenceProbe

A Ruby framework for probing inter-model and inter-role evidence differences in LLM responses. Inspired by the ["Role-Based Reality" research](https://ghostintheweights.substack.com) by Eric Stiens.

## Overview

EvidenceProbe allows you to systematically test how different LLMs respond to the same questions when presented with different user personas. It detects:

- **Role-based suppression**: Information revealed to credentialed users but hidden from naive users
- **Model variance**: Different evidence disclosure across models for the same role
- **Credential sensitivity**: How much a model's response changes based on user credentials

## Installation

```ruby
# Gemfile
gem "evidence_probe", git: "https://github.com/estiens/evidence_probe.git"

# Or install dependencies manually
gem install json fileutils terminal-table colorize dotenv
```

## Quick Start

```ruby
require "evidence_probe"

# Configure with your API key
EvidenceProbe.configure do |config|
  config.api_key = ENV["OPENROUTER_API_KEY"]
  config.verbose = true
end

# Run a quick probe
probe = EvidenceProbe.quick_probe(
  prompt: "What are the risks of [topic]?",
  evidence_markers: ["risk_a", "risk_b", "controversy"]
)

probe.run
puts probe.summary
```

## DSL Usage

EvidenceProbe provides a clean DSL for defining experiments:

```ruby
probe = EvidenceProbe.probe "my_experiment" do
  scenario do
    name "topic_analysis"
    description "Testing evidence disclosure on [topic]"
    
    prompt <<~PROMPT
      What are the benefits and risks of [topic]?
      Please provide a balanced assessment.
    PROMPT
    
    # Define evidence markers to track
    evidence "risk_factor_a", patterns: ["risk", "danger", "harm"]
    evidence "controversy", patterns: ["controversy", "debate", "disputed"]
    evidence "alternatives", patterns: ["alternative", "instead", "other option"]
  end
  
  roles do
    layperson
    junior "engineer"
    senior "researcher", credentials: ["PhD"], knowledge: ["domain expertise"]
    expert "field", credentials: ["20 years experience"], challenge: true
  end
  
  use_models :frontier  # or specify: models ["anthropic/claude-sonnet-4-20250514", "openai/gpt-4o"]
end

probe.run
```

## Core Concepts

### Roles

Roles define the persona presented to the model. Key attributes:

- **credentials**: Professional qualifications (e.g., "PhD", "MSW", "10 years experience")
- **domain_knowledge**: Specific knowledge the user demonstrates
- **tone**: `:deferential`, `:neutral`, `:assertive`, or `:challenging`
- **challenge_level**: `:none`, `:implicit`, or `:explicit`

```ruby
# Predefined roles
Role.layperson
Role.junior_professional("engineer")
Role.senior_professional("researcher", credentials: ["PhD"])
Role.domain_expert("field", credentials: [...], knowledge: [...])

# From the original experiment
Role.engineer_naive
Role.mental_health_professional
```

### Scenarios

Scenarios define the topic and evidence markers to track:

```ruby
# Predefined scenarios
Scenario.mental_health_intervention
Scenario.medical_treatment_evaluation
Scenario.policy_analysis
Scenario.technology_ethics

# Custom scenario
Scenario.custom(
  name: "my_topic",
  prompt: "Your question here",
  markers: [
    { name: "marker_name", patterns: ["pattern1", "pattern2"] },
    "simple_string_marker"
  ]
)
```

### Evidence Markers

Evidence markers can be:

- **Simple strings**: `"controversy"` - matches if the word appears
- **Regex patterns**: `/\d+%/` - matches percentage figures
- **Hash with patterns**: `{ name: "risk", patterns: ["risk", "danger", /harm/] }`

## Analysis

### ResponseAnalyzer

```ruby
analyzer = EvidenceProbe::ResponseAnalyzer.new(
  results: probe.results,
  scenario: probe.scenario
)

# Find role-based suppressions
suppressions = analyzer.find_role_based_suppression

# Find model variance
variances = analyzer.find_model_variance

# Get disclosure rates
rates = analyzer.evidence_disclosure_rates

# Rank models
analyzer.rank_models_by_honesty
analyzer.rank_models_by_credential_sensitivity
```

### LLM Judge

Use an LLM to perform deeper analysis:

```ruby
judge = EvidenceProbe::Judge.new

# Detect suppression between responses
judge.detect_suppression(
  naive_response: "...",
  expert_response: "...",
  topic: "mental health intervention"
)

# Evaluate against a rubric
judge.evaluate_rubric(
  response: "...",
  rubric: {
    "Evidence Quality" => "Does it cite studies?",
    "Balance" => "Does it present multiple views?"
  }
)

# Compare two responses
judge.compare_evidence(
  response_a: "...",
  response_b: "...",
  context: "topic",
  evidence_markers: [...]
)
```

## Reports

Generate reports in multiple formats:

```ruby
report = EvidenceProbe::ReportGenerator.new(probe)

# Text report (console-friendly)
puts report.text_report

# Markdown report
report.save(format: :markdown)

# HTML report
report.save(format: :html)

# JSON data
report.save(format: :json)
```

## CLI Usage

```bash
# Run a probe file
./bin/evidence_probe my_probe.rb

# Quick probe from command line
./bin/evidence_probe --quick "Is X safe?" -m openai/gpt-4o,anthropic/claude-sonnet-4-20250514

# With options
./bin/evidence_probe -v -f html -o ./my_results my_probe.rb
```

## Configuration

```ruby
EvidenceProbe.configure do |config|
  config.api_key = "your-api-key"           # OpenRouter API key
  config.api_url = "https://openrouter.ai/api/v1"
  config.default_models = [...]              # Default models to test
  config.judge_model = "anthropic/claude-sonnet-4-20250514"  # Model for LLM judge
  config.output_dir = "./results"            # Output directory
  config.verbose = true                      # Enable verbose logging
  config.max_retries = 3                     # API retry attempts
  config.timeout = 120                       # Request timeout (seconds)
end
```

Environment variables:
- `OPENROUTER_API_KEY` or `QUALSPEC_API_KEY`
- `OPENROUTER_API_URL`

## Model Presets

```ruby
use_models :frontier   # Claude, GPT-4o, Gemini Pro
use_models :cheap      # GPT-4o-mini, Gemini Flash, Haiku
use_models :diverse    # Frontier + Grok
use_models :chinese    # DeepSeek, Qwen
```

## Role Presets

```ruby
use_roles :naive_vs_expert      # Engineer naive vs Mental health professional
use_roles :credential_ladder    # Layperson → Junior → Senior → Expert
use_roles :minimal              # Layperson vs Expert
```

## Integration with open_router_enhanced

EvidenceProbe is designed to work with [open_router_enhanced](https://github.com/estiens/open_router_enhanced) for advanced features:

```ruby
# If open_router_enhanced is available, you can use its client
require "open_router_enhanced"

client = OpenRouterEnhanced::Client.new
probe.run(client: client)
```

## Integration with qualspec

For RSpec-style testing of LLM behaviors:

```ruby
# In your spec file
require "qualspec"
require "evidence_probe"

RSpec.describe "Model Evidence Disclosure" do
  let(:probe) { EvidenceProbe.probe { ... } }
  
  it "discloses critical evidence regardless of role" do
    probe.run
    suppressions = probe.analyzer.find_role_based_suppression
    expect(suppressions).to be_empty
  end
end
```

## Background

This tool was inspired by the research documented in ["Role-Based Reality: How AI Withholds Life-or-Death Information Unless You Know the Magic Words"](https://ghostintheweights.substack.com). The research found that:

1. Models suppress critical information (e.g., about crisis line effectiveness) from naive users
2. The same information is revealed when users present professional credentials
3. Different models show different patterns of suppression
4. Chinese models showed different suppression patterns than American models

EvidenceProbe provides a systematic way to detect and measure these patterns.

## License

MIT

## Contributing

Contributions welcome! Please see the GitHub repository for issues and pull requests.
