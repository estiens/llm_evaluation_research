# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EvidenceProbe::Role do
  describe '#initialize' do
    it 'creates a role with required attributes' do
      role = described_class.new(name: 'test_role')
      expect(role.name).to eq 'test_role'
    end

    it 'accepts all optional attributes' do
      role = described_class.new(
        name: 'expert',
        description: 'Domain expert',
        credentials: ['PhD', '10 years'],
        domain_knowledge: ['topic expertise'],
        tone: :assertive,
        challenge_level: :explicit
      )

      expect(role.credentials).to eq ['PhD', '10 years']
      expect(role.tone).to eq :assertive
    end
  end

  describe '#preamble' do
    it 'returns empty string for layperson with no credentials' do
      role = described_class.layperson
      expect(role.preamble).to include('regular person')
    end

    it 'includes credentials when present' do
      role = described_class.new(
        name: 'expert',
        credentials: ['PhD in Psychology']
      )
      expect(role.preamble).to include('PhD in Psychology')
    end

    it 'includes domain knowledge when present' do
      role = described_class.new(
        name: 'expert',
        domain_knowledge: ['crisis intervention']
      )
      expect(role.preamble).to include('crisis intervention')
    end
  end

  describe '#apply_to' do
    it 'prepends preamble to base prompt' do
      role = described_class.new(
        name: 'expert',
        description: 'I am an expert.'
      )
      result = role.apply_to('What is your opinion?')
      expect(result).to include('I am an expert.')
      expect(result).to include('What is your opinion?')
    end
  end

  describe '.layperson' do
    it 'creates a layperson role' do
      role = described_class.layperson
      expect(role.name).to eq 'layperson'
      expect(role.tone).to eq :deferential
      expect(role.credentials).to be_empty
    end
  end

  describe '.junior_professional' do
    it 'creates a junior professional role' do
      role = described_class.junior_professional('engineer')
      expect(role.name).to eq 'junior_engineer'
      expect(role.tone).to eq :neutral
    end
  end

  describe '.senior_professional' do
    it 'creates a senior professional role with credentials' do
      role = described_class.senior_professional('researcher', credentials: ['PhD'])
      expect(role.name).to eq 'senior_researcher'
      expect(role.credentials).to include('PhD')
      expect(role.tone).to eq :assertive
    end
  end

  describe '.domain_expert' do
    it 'creates a domain expert role' do
      role = described_class.domain_expert('psychology', credentials: ['PhD'], knowledge: ['clinical'])
      expect(role.name).to eq 'expert_psychology'
      expect(role.tone).to eq :challenging
      expect(role.challenge_level).to eq :explicit
    end
  end

  describe '.mental_health_professional' do
    it 'creates the original experiment role' do
      role = described_class.mental_health_professional
      expect(role.name).to eq 'mental_health_professional'
      expect(role.credentials).to include('MSW (Master of Social Work)')
      expect(role.domain_knowledge).to include('Crisis lines that involve police dispatch')
    end
  end
end
