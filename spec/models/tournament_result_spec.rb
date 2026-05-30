# frozen_string_literal: true

require "rails_helper"

RSpec.describe TournamentResult do
  let(:tournament) { Tournament.create!(name: "Test", starts_at: 1.day.ago) }
  let(:golfer) { Golfer.create!(name: "Player", external_id: "1") }
  let(:result) { described_class.new(tournament: tournament, golfer: golfer) }

  describe "MISSED_CUT_POSITIONS" do
    it "includes CUT and WD" do
      expect(described_class::MISSED_CUT_POSITIONS).to include("CUT", "WD")
    end
  end

  describe "#missed_cut?" do
    it "returns true when position_display is CUT" do
      result.position_display = "CUT"
      expect(result.missed_cut?).to be true
    end

    it "returns true when position_display is WD" do
      result.position_display = "WD"
      expect(result.missed_cut?).to be true
    end

    it "returns false when position_display is T18" do
      result.position_display = "T18"
      expect(result.missed_cut?).to be false
    end

    it "falls back to prize_money when position_display is blank" do
      result.position_display = nil
      result.prize_money = 0
      expect(result.missed_cut?).to be true
    end

    it "returns false when position_display blank and prize_money positive" do
      result.position_display = nil
      result.prize_money = 50_000
      expect(result.missed_cut?).to be false
    end
  end

  describe "#made_cut_for_bonus?" do
    it "returns false when missed cut" do
      result.position_display = "CUT"
      expect(result.made_cut_for_bonus?).to be false
    end

    it "returns true when position_display indicates made cut" do
      result.position_display = "T42"
      expect(result.made_cut_for_bonus?).to be true
    end

    it "returns false when position_display blank and prize_money zero" do
      result.position_display = nil
      result.prize_money = 0
      expect(result.made_cut_for_bonus?).to be false
    end

    it "returns true when position_display blank and prize_money positive" do
      result.position_display = nil
      result.prize_money = 10_000
      expect(result.made_cut_for_bonus?).to be true
    end
  end
end
