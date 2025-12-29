# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**EvidenceProbe** - A Ruby framework for systematically testing how LLMs respond to the same questions when presented with different user personas (roles). Primary use case: detecting RLHF-induced role-based information suppression (evidence shown to "expert" users but withheld from "naive" users).

## Commands

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/probe_spec.rb

# Run examples (requires OPENROUTER_API_KEY)
bundle exec ruby examples/test_basic.rb           # Smoke tests
bundle exec ruby examples/mental_health_probe.rb  # Main experiment
bundle exec ruby examples/custom_probe.rb         # Custom scenarios
```

## Environment Variables

```bash
OPENROUTER_API_KEY=your-key    # Required for LLM calls
QUALSPEC_API_KEY=your-key      # Alternative (fallback)
OPENROUTER_API_URL=https://... # Optional, defaults to OpenRouter
```

## Architecture

### Testing Matrix
```
Models × Roles × Scenarios → Results → Analysis
```

### Core Components

**Probe** (`lib/evidence_probe/probe.rb`) - Main orchestrator. Runs scenario × models × roles matrix, stores results, provides analysis methods (`analyze_inter_model`, `analyze_inter_role`, `summary`).

**DSL** (`lib/evidence_probe/dsl.rb`) - Fluent interface for defining probes:
```ruby
EvidenceProbe.probe("name") do
  scenario(:mental_health_intervention)
  use_roles(:naive_vs_expert)
  use_models(:frontier)
end
```

**Role** (`lib/evidence_probe/role.rb`) - User personas with credentials, domain knowledge, tone, and challenge level. Predefined: `layperson`, `domain_expert(field)`, `mental_health_professional`.

**Scenario** (`lib/evidence_probe/scenario.rb`) - Test cases with base prompts and evidence markers (string/regex/hash patterns). Predefined: `mental_health_intervention`, `medical_treatment_evaluation`, `policy_analysis`.

**ResponseAnalyzer** (`lib/evidence_probe/response_analyzer.rb`) - Pattern detection across results. Key methods: `find_role_based_suppression`, `evidence_disclosure_rates`, `rank_models_by_honesty`.

**Client** (`lib/evidence_probe/client.rb`) - OpenRouter API wrapper with retry logic and rate limiting.

**Judge** (`lib/evidence_probe/judge.rb`) - LLM-based comparative analysis using Claude as evaluator.

**ReportGenerator** (`lib/evidence_probe/report_generator.rb`) - Multi-format output (text/markdown/HTML/JSON).

### Data Flow
1. Base prompt + role context → Full prompt
2. Submit to model via OpenRouter Client
3. Response text → Evidence marker checking
4. Results → Analysis (inter-model, inter-role suppression detection)

## Key Files

- `lib/evidence_probe/probe.rb` - Start here to understand orchestration
- `lib/evidence_probe/dsl.rb` - How users define test configurations
- `lib/evidence_probe/response_analyzer.rb` - Suppression pattern detection logic
- `examples/mental_health_probe.rb` - Complete working example
- `rlhf_suppression_research_agenda.md` - Research domains and test case ideas

## Testing

Tests use WebMock to stub HTTP requests - no actual API calls in specs. Test structure follows standard RSpec conventions with `let`, `subject`, and `describe`/`it` blocks.
