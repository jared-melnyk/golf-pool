# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChaChaCha do
  describe ".scores_to_count" do
    it { expect(described_class.scores_to_count(1)).to eq(1) }
    it { expect(described_class.scores_to_count(2)).to eq(2) }
    it { expect(described_class.scores_to_count(3)).to eq(3) }
    it { expect(described_class.scores_to_count(4)).to eq(1) }
    it { expect(described_class.scores_to_count(18)).to eq(3) }
  end

  describe ".valid_team_size?" do
    it { expect(described_class.valid_team_size?(3)).to be true }
    it { expect(described_class.valid_team_size?(4)).to be true }
    it { expect(described_class.valid_team_size?(2)).to be false }
    it { expect(described_class.valid_team_size?(5)).to be false }
  end
end
