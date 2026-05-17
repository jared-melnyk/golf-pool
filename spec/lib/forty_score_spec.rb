# frozen_string_literal: true

require "rails_helper"

RSpec.describe FortyScore do
  describe ".target_pick_count" do
    it { expect(described_class.target_pick_count(3)).to eq(30) }
    it { expect(described_class.target_pick_count(4)).to eq(40) }
  end

  describe ".competition_multiplier" do
    it { expect(described_class.competition_multiplier(3)).to eq(4.0 / 3.0) }
    it { expect(described_class.competition_multiplier(4)).to eq(1.0) }
  end

  describe ".competition_vs_par" do
    it "rounds threesome actual to nearest whole stroke" do
      expect(described_class.competition_vs_par(actual_vs_par: 8, player_count: 3)).to eq(11)
    end

    it "returns actual unchanged for foursomes" do
      expect(described_class.competition_vs_par(actual_vs_par: 8, player_count: 4)).to eq(8)
    end
  end

  describe ".valid_team_size?" do
    it { expect(described_class.valid_team_size?(3)).to be true }
    it { expect(described_class.valid_team_size?(4)).to be true }
    it { expect(described_class.valid_team_size?(2)).to be false }
  end
end
