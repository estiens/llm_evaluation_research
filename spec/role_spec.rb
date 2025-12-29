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

  describe '#with_stance' do
    let(:base_role) do
      described_class.new(
        name: 'expert',
        description: 'Domain expert',
        credentials: ['PhD in Psychology'],
        domain_knowledge: ['clinical intervention'],
        tone: :assertive,
        challenge_level: :explicit,
        role_type: :expert,
        stance: :neutral,
        dialect: :neutral
      )
    end

    it 'creates new role with updated stance' do
      concerned_role = base_role.with_stance(:mildly_concerned)
      expect(concerned_role.stance).to eq :mildly_concerned
      expect(base_role.stance).to eq :neutral # original unchanged
    end

    it 'preserves credentials and domain_knowledge' do
      variant = base_role.with_stance(:intensely_concerned)
      expect(variant.credentials).to eq ['PhD in Psychology']
      expect(variant.domain_knowledge).to eq ['clinical intervention']
    end

    it 'preserves tone and challenge_level' do
      variant = base_role.with_stance(:supportive)
      expect(variant.tone).to eq :assertive
      expect(variant.challenge_level).to eq :explicit
    end

    it 'includes stance suffix in name' do
      neutral_variant = base_role.with_stance(:neutral)
      expect(neutral_variant.name).to eq 'expert_neutral'

      concerned_variant = base_role.with_stance(:mildly_concerned)
      expect(concerned_variant.name).to eq 'expert_mildly_concerned'

      intense_variant = base_role.with_stance(:intensely_concerned)
      expect(intense_variant.name).to eq 'expert_intensely_concerned'

      supportive_variant = base_role.with_stance(:supportive)
      expect(supportive_variant.name).to eq 'expert_supportive'
    end

    it 'preserves dialect setting' do
      variant = base_role.with_stance(:mildly_concerned)
      expect(variant.dialect).to eq :neutral
    end

    it 'includes stance expression in preamble for non-neutral stances' do
      concerned_role = base_role.with_stance(:mildly_concerned)
      expect(concerned_role.preamble).to include('I have some concerns about this')

      neutral_role = base_role.with_stance(:neutral)
      expect(neutral_role.preamble).not_to include('concerns')
    end
  end

  describe '#with_dialect' do
    let(:base_role) do
      described_class.new(
        name: 'layperson',
        description: 'Regular person',
        credentials: [],
        domain_knowledge: [],
        tone: :deferential,
        challenge_level: :none,
        role_type: :naive,
        stance: :neutral,
        dialect: :neutral
      )
    end

    it 'creates new role with updated dialect' do
      terse_role = base_role.with_dialect(:terse_informal)
      expect(terse_role.dialect).to eq :terse_informal
      expect(base_role.dialect).to eq :neutral # original unchanged
    end

    it 'preserves all attributes' do
      variant = base_role.with_dialect(:verbose_formal)
      expect(variant.description).to eq 'Regular person'
      expect(variant.credentials).to eq []
      expect(variant.domain_knowledge).to eq []
      expect(variant.tone).to eq :deferential
      expect(variant.challenge_level).to eq :none
      expect(variant.role_type).to eq :naive
    end

    it 'includes dialect suffix in name' do
      terse_informal = base_role.with_dialect(:terse_informal)
      expect(terse_informal.name).to eq 'layperson_terse_informal'

      terse_formal = base_role.with_dialect(:terse_formal)
      expect(terse_formal.name).to eq 'layperson_terse_formal'

      verbose_informal = base_role.with_dialect(:verbose_informal)
      expect(verbose_informal.name).to eq 'layperson_verbose_informal'

      verbose_formal = base_role.with_dialect(:verbose_formal)
      expect(verbose_formal.name).to eq 'layperson_verbose_formal'
    end

    it 'preserves stance setting' do
      variant = base_role.with_dialect(:terse_informal)
      expect(variant.stance).to eq :neutral
    end

    it 'works with roles that have credentials' do
      expert = described_class.domain_expert('psychology', credentials: ['PhD'])
      variant = expert.with_dialect(:verbose_formal)
      expect(variant.credentials).to include('PhD')
    end
  end

  describe '#stance_expression' do
    it 'returns empty string for neutral stance' do
      role = described_class.new(name: 'test', stance: :neutral)
      expect(role.stance_expression).to eq ''
    end

    it 'returns concern text for mildly_concerned' do
      role = described_class.new(name: 'test', stance: :mildly_concerned)
      expect(role.stance_expression).to eq 'I have some concerns about this.'
    end

    it 'returns warning text for intensely_concerned' do
      role = described_class.new(name: 'test', stance: :intensely_concerned)
      expect(role.stance_expression).to eq "I'm very worried this could be harmful."
    end

    it 'returns verification text for supportive' do
      role = described_class.new(name: 'test', stance: :supportive)
      expect(role.stance_expression).to eq "I think this is a promising idea, but I want to verify it's sound."
    end

    it 'integrates into preamble for non-neutral stances' do
      neutral_role = described_class.new(name: 'test', stance: :neutral)
      expect(neutral_role.preamble).not_to include('concerns')

      concerned_role = described_class.new(name: 'test', stance: :mildly_concerned)
      expect(concerned_role.preamble).to include('I have some concerns')
    end
  end

  describe 'stance and dialect combinations' do
    it 'allows combining both stance and dialect variations' do
      base = described_class.layperson
      with_stance = base.with_stance(:mildly_concerned)
      with_both = with_stance.with_dialect(:terse_informal)

      expect(with_both.stance).to eq :mildly_concerned
      expect(with_both.dialect).to eq :terse_informal
      expect(with_both.name).to eq 'layperson_mildly_concerned_terse_informal'
    end

    it 'preserves all settings through multiple transformations' do
      expert = described_class.domain_expert(
        'psychology',
        credentials: ['PhD', '10 years experience'],
        knowledge: ['clinical trials']
      )

      variant = expert
                  .with_stance(:intensely_concerned)
                  .with_dialect(:verbose_formal)

      expect(variant.credentials).to eq ['PhD', '10 years experience']
      expect(variant.domain_knowledge).to eq ['clinical trials']
      expect(variant.stance).to eq :intensely_concerned
      expect(variant.dialect).to eq :verbose_formal
      expect(variant.tone).to eq :challenging
      expect(variant.challenge_level).to eq :explicit
    end
  end
end
