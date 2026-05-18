# frozen_string_literal: true

require "rails_helper"

RSpec.describe Games::ScorecardHelper, type: :helper do
  describe "#scorecard_display_rank" do
    let(:leaderboard) do
      [
        { rank: 1, team_name: "A" },
        { rank: 2, team_name: "B" }
      ]
    end

    it "returns plain position when not tied" do
      expect(helper.scorecard_display_rank(1, leaderboard)).to eq("1")
      expect(helper.scorecard_display_rank(2, leaderboard)).to eq("2")
    end

    it "returns T prefix when multiple teams share a rank" do
      tied = [
        { rank: 1, team_name: "A" },
        { rank: 1, team_name: "B" },
        { rank: 3, team_name: "C" }
      ]
      expect(helper.scorecard_display_rank(1, tied)).to eq("T1")
      expect(helper.scorecard_display_rank(3, tied)).to eq("3")
    end

    it "returns em dash when rank is nil" do
      expect(helper.scorecard_display_rank(nil, leaderboard)).to eq("—")
    end
  end
end
