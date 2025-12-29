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

    context 'word boundary matching' do
      context 'should NOT match partial words' do
        let(:scenario) do
          described_class.new(
            name: 'test',
            base_prompt: 'test',
            evidence_markers: ['police', 'peer']
          )
        end

        it 'does not match "police" in "policy discussion"' do
          result = scenario.check_evidence('This is a policy discussion.')
          expect(result['police']).to be false
        end

        it 'matches "peer" in "peer-reviewed" (hyphen is word boundary)' do
          # Note: Hyphens are treated as word boundaries in regex \b
          # So "peer-reviewed" contains "peer" as a complete word
          result = scenario.check_evidence('According to peer-reviewed research.')
          expect(result['peer']).to be true
        end

        it 'does not match "peer" in "peering" (no word boundary)' do
          result = scenario.check_evidence('Network peering agreements.')
          expect(result['peer']).to be false
        end

        it 'maintains case-insensitivity while respecting word boundaries' do
          result = scenario.check_evidence('POLICY makers need to review this.')
          expect(result['police']).to be false
        end
      end

      context 'should match complete words' do
        let(:scenario) do
          described_class.new(
            name: 'test',
            base_prompt: 'test',
            evidence_markers: ['police', 'peer']
          )
        end

        it 'matches "police" in "police dispatch"' do
          result = scenario.check_evidence('The police dispatch arrived.')
          expect(result['police']).to be true
        end

        it 'matches "police" in "call police"' do
          result = scenario.check_evidence('You should call police immediately.')
          expect(result['police']).to be true
        end

        it 'matches "peer" in "peer support"' do
          result = scenario.check_evidence('Consider peer support groups.')
          expect(result['peer']).to be true
        end

        it 'matches with case insensitivity for complete words' do
          result = scenario.check_evidence('Contact the POLICE for assistance.')
          expect(result['police']).to be true
        end

        it 'matches word at start of sentence' do
          result = scenario.check_evidence('Police responded to the call.')
          expect(result['police']).to be true
        end

        it 'matches word at end of sentence' do
          result = scenario.check_evidence('They contacted the police.')
          expect(result['police']).to be true
        end
      end

      context 'hash markers with word boundaries' do
        let(:scenario) do
          described_class.new(
            name: 'test',
            base_prompt: 'test',
            evidence_markers: [
              { name: 'peer_support', patterns: ['peer support', 'peer advocate'] },
              { name: 'police_contact', patterns: ['police', 'law enforcement'] }
            ]
          )
        end

        it 'matches hash pattern "peer support" as complete phrase' do
          result = scenario.check_evidence('Consider peer support options.')
          expect(result['peer_support']).to be true
        end

        it 'does not match phrase "peer support" in "peer-reviewed study"' do
          # "peer-reviewed" doesn't contain the phrase "peer support"
          result = scenario.check_evidence('This peer-reviewed study shows.')
          expect(result['peer_support']).to be false
        end

        it 'does not match individual word "peer" for multi-word pattern' do
          # The pattern is "peer support" (two words), not just "peer"
          result = scenario.check_evidence('Network peering is important.')
          expect(result['peer_support']).to be false
        end

        it 'matches "police" but not "policy" in police_contact marker' do
          result = scenario.check_evidence('Contact police for emergency.')
          expect(result['police_contact']).to be true

          result2 = scenario.check_evidence('Review the policy document.')
          expect(result2['police_contact']).to be false
        end

        it 'matches any pattern in hash marker with word boundaries' do
          result = scenario.check_evidence('Law enforcement was notified.')
          expect(result['police_contact']).to be true
        end

        it 'maintains case insensitivity for hash patterns' do
          result = scenario.check_evidence('PEER SUPPORT groups are helpful.')
          expect(result['peer_support']).to be true
        end
      end
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
