# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EvidenceProbe::Scenario do
  describe '#initialize' do
    it 'creates a scenario with required attributes' do
      scenario = described_class.new(
        name: 'test_scenario',
        base_prompt: 'What do you think?'
      )
      expect(scenario.name).to eq 'test_scenario'
      expect(scenario.base_prompt).to eq 'What do you think?'
    end

    it 'defaults sensitivity_level to :medium' do
      scenario = described_class.new(name: 'test', base_prompt: 'test')
      expect(scenario.sensitivity_level).to eq :medium
    end
  end

  describe '#prompt_for' do
    it 'applies role context to base prompt' do
      scenario = described_class.new(
        name: 'test',
        base_prompt: 'Is this safe?'
      )
      role = EvidenceProbe::Role.new(
        name: 'expert',
        description: 'I am a domain expert.'
      )

      result = scenario.prompt_for(role)
      expect(result).to include('domain expert')
      expect(result).to include('Is this safe?')
    end
  end

  describe '#check_evidence' do
    let(:scenario) do
      described_class.new(
        name: 'test',
        base_prompt: 'test',
        evidence_markers: [
          'risk',
          /\d+%/,
          { name: 'controversy', patterns: ['debate', 'disputed'] }
        ]
      )
    end

    it 'detects simple string markers (case insensitive)' do
      result = scenario.check_evidence('There is significant RISK involved.')
      expect(result['risk']).to be true
    end

    it 'detects regex markers' do
      result = scenario.check_evidence('Studies show 44% effectiveness.')
      expect(result['\d+%']).to be true
    end

    it 'detects hash markers with patterns' do
      result = scenario.check_evidence('This is a disputed topic.')
      expect(result['controversy']).to be true
    end

    it 'returns false for missing markers' do
      result = scenario.check_evidence('Everything is fine.')
      expect(result['risk']).to be false
      expect(result['controversy']).to be false
    end
  end

  describe '.mental_health_intervention' do
    it 'creates the predefined scenario' do
      scenario = described_class.mental_health_intervention
      expect(scenario.name).to eq 'mental_health_intervention'
      expect(scenario.sensitivity_level).to eq :high
      expect(scenario.evidence_markers).not_to be_empty
    end

    it 'includes expected evidence markers' do
      scenario = described_class.mental_health_intervention
      marker_names = scenario.evidence_markers.map { |m| m[:name] }
      expect(marker_names).to include('police_dispatch')
      expect(marker_names).to include('abandonment_rates')
      expect(marker_names).to include('surveillance_fears')
    end
  end

  describe '.custom' do
    it 'creates a custom scenario' do
      scenario = described_class.custom(
        name: 'my_test',
        prompt: 'Custom question',
        markers: ['evidence_a', 'evidence_b'],
        sensitivity: :low
      )
      expect(scenario.name).to eq 'my_test'
      expect(scenario.base_prompt).to eq 'Custom question'
      expect(scenario.sensitivity_level).to eq :low
    end
  end
end
