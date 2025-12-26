# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EvidenceProbe do
  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(described_class.configuration).to be_a(EvidenceProbe::Configuration)
    end

    it 'memoizes the configuration' do
      expect(described_class.configuration).to be(described_class.configuration)
    end
  end

  describe '.configure' do
    it 'yields the configuration' do
      described_class.configure do |config|
        config.verbose = true
        config.timeout = 60
      end

      expect(described_class.configuration.verbose).to be true
      expect(described_class.configuration.timeout).to eq 60
    end
  end

  describe '.reset!' do
    it 'clears the configuration' do
      described_class.configure { |c| c.verbose = true }
      described_class.reset!
      expect(described_class.configuration.verbose).to be false
    end
  end
end
