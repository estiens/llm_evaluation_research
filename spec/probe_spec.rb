# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EvidenceProbe::Probe do
  let(:scenario) do
    EvidenceProbe::Scenario.new(
      name: 'test_scenario',
      base_prompt: 'Is this safe?',
      evidence_markers: ['risk', 'benefit']
    )
  end

  let(:roles) do
    [
      EvidenceProbe::Role.layperson,
      EvidenceProbe::Role.domain_expert('field')
    ]
  end

  let(:models) { %w[model-a model-b] }

  subject(:probe) do
    described_class.new(scenario: scenario, roles: roles, models: models)
  end

  describe '#initialize' do
    it 'stores the scenario' do
      expect(probe.scenario).to eq scenario
    end

    it 'stores the roles' do
      expect(probe.roles).to eq roles
    end

    it 'stores the models' do
      expect(probe.models).to eq models
    end

    it 'initializes empty results' do
      expect(probe.results).to eq []
    end

    it 'generates a timestamp' do
      expect(probe.timestamp).to match(/\d{8}_\d{6}/)
    end
  end

  describe '#initialize with defaults' do
    it 'uses default roles when none provided' do
      probe = described_class.new(scenario: scenario, roles: [], models: models)
      expect(probe.roles).not_to be_empty
    end

    it 'uses default models when none provided' do
      probe = described_class.new(scenario: scenario, roles: roles, models: nil)
      expect(probe.models).not_to be_empty
    end
  end

  describe '#summary' do
    it 'returns empty hash when no results' do
      expect(probe.summary).to eq({})
    end
  end

  describe '#analyze_inter_model' do
    it 'returns empty hash when no results' do
      expect(probe.analyze_inter_model).to eq({})
    end
  end

  describe '#analyze_inter_role' do
    it 'returns empty hash when no results' do
      expect(probe.analyze_inter_role).to eq({})
    end
  end

  describe '#to_json' do
    it 'serializes to JSON' do
      json = probe.to_json
      parsed = JSON.parse(json)
      expect(parsed).to have_key('summary')
      expect(parsed).to have_key('results')
    end
  end
end
