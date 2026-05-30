# frozen_string_literal: true

require "rails_helper"

RSpec.describe TournamentsHelper, type: :helper do
  let(:tournament) { Tournament.create!(name: "Test", starts_at: 1.day.ago) }

  def build_result(attrs)
    golfer = Golfer.create!(name: "G#{SecureRandom.hex(2)}", external_id: SecureRandom.hex(4))
    TournamentResult.new({ tournament: tournament, golfer: golfer }.merge(attrs))
  end

  describe "#missed_cut?" do
    it "returns true when prize_money is nil" do
      result = build_result(position: 1, prize_money: nil)
      expect(helper.missed_cut?(result)).to be true
    end

    it "returns true when prize_money is zero" do
      result = build_result(position: 50, prize_money: 0)
      expect(helper.missed_cut?(result)).to be true
    end

    it "returns false when prize_money is positive" do
      result = build_result(position: 1, prize_money: 1_000_000)
      expect(helper.missed_cut?(result)).to be false
    end

    it "returns true when position_display is CUT" do
      result = build_result(position_display: "CUT", prize_money: nil)
      expect(helper.missed_cut?(result)).to be true
    end
  end

  describe "#display_place" do
    it "returns CUT when position_display is CUT" do
      result = build_result(position_display: "CUT", prize_money: nil)
      expect(helper.display_place(result, [ result ])).to eq("CUT")
    end

    it "returns MC when result is missed cut (prize_money nil)" do
      result = build_result(position: 75, prize_money: nil)
      expect(helper.display_place(result, [ result ])).to eq("MC")
    end

    it "returns MC when result is missed cut (prize_money zero)" do
      result = build_result(position: 80, prize_money: 0)
      expect(helper.display_place(result, [ result ])).to eq("MC")
    end

    it "returns MC when position is nil (even with prize money)" do
      result = build_result(position: nil, prize_money: 100)
      expect(helper.display_place(result, [ result ])).to eq("MC")
    end

    it "returns solo place number when one result at that position" do
      result = build_result(position: 1, prize_money: 2_000_000)
      expect(helper.display_place(result, [ result ])).to eq("1")
    end

    it "returns T plus position when multiple results share the same position" do
      r1 = build_result(position: 3, prize_money: 500_000)
      r2 = build_result(position: 3, prize_money: 500_000)
      r3 = build_result(position: 3, prize_money: 500_000)
      results = [ r1, r2, r3 ]
      results.each do |r|
        expect(helper.display_place(r, results)).to eq("T3")
      end
    end

    it "does not count missed-cut results when determining ties" do
      r1 = build_result(position: 2, prize_money: 1_000_000)
      r2_mc = build_result(position: 2, prize_money: 0)
      results = [ r1, r2_mc ]
      expect(helper.display_place(r1, results)).to eq("2")
      expect(helper.display_place(r2_mc, results)).to eq("MC")
    end
  end
end
