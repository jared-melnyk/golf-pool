# frozen_string_literal: true

require "rails_helper"

RSpec.describe Vegas do
  describe ".cap_net" do
    it { expect(described_class.cap_net(8)).to eq(8) }
    it { expect(described_class.cap_net(9)).to eq(9) }
    it { expect(described_class.cap_net(10)).to eq(9) }
    it { expect(described_class.cap_net(11)).to eq(9) }
    it { expect(described_class.cap_net(nil)).to be_nil }
  end

  describe ".team_number" do
    it "pairs lower net as tens and higher as ones" do
      expect(described_class.team_number(3, 4)).to eq(34)
      expect(described_class.team_number(4, 6)).to eq(46)
      expect(described_class.team_number(4, 4)).to eq(44)
    end

    it "flips digit order when flipped is true" do
      expect(described_class.team_number(4, 5, flipped: true)).to eq(54)
    end
  end

  describe ".birdie_or_better?" do
    it { expect(described_class.birdie_or_better?(3, 4)).to be true }
    it { expect(described_class.birdie_or_better?(2, 4)).to be true }
    it { expect(described_class.birdie_or_better?(4, 4)).to be false }
    it { expect(described_class.birdie_or_better?(nil, 4)).to be false }
  end

  describe ".hole_points" do
    it "returns positive points when reference team wins" do
      expect(described_class.hole_points(34, 46)).to eq(12)
    end

    it "returns negative points when reference team loses" do
      expect(described_class.hole_points(46, 34)).to eq(-12)
    end

    it "returns zero on a tie" do
      expect(described_class.hole_points(44, 44)).to eq(0)
    end
  end

  describe ".valid_game_roster?" do
    it { expect(described_class.valid_game_roster?([ [ 1, 2 ], [ 3, 4 ] ])).to be true }
    it { expect(described_class.valid_game_roster?([ [ 1, 2, 3 ], [ 4, 5, 6 ] ])).to be false }
    it { expect(described_class.valid_game_roster?([ [ 1, 2 ] ])).to be false }
    it { expect(described_class.valid_game_roster?([ [ 1 ], [ 2, 3 ] ])).to be false }
  end
end
