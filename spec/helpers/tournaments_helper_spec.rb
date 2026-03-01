# frozen_string_literal: true

require "rails_helper"

RSpec.describe TournamentsHelper, type: :helper do
  describe "#missed_cut?" do
    it "returns true when prize_money is nil" do
      result = double("result", position: 1, prize_money: nil)
      expect(helper.missed_cut?(result)).to be true
    end

    it "returns true when prize_money is zero" do
      result = double("result", position: 50, prize_money: 0)
      expect(helper.missed_cut?(result)).to be true
    end

    it "returns false when prize_money is positive" do
      result = double("result", position: 1, prize_money: 1_000_000)
      expect(helper.missed_cut?(result)).to be false
    end
  end

  describe "#display_place" do
    it "returns MC when result is missed cut (prize_money nil)" do
      result = double("result", position: 75, prize_money: nil)
      expect(helper.display_place(result, [ result ])).to eq("MC")
    end

    it "returns MC when result is missed cut (prize_money zero)" do
      result = double("result", position: 80, prize_money: 0)
      expect(helper.display_place(result, [ result ])).to eq("MC")
    end

    it "returns MC when position is nil (even with prize money)" do
      result = double("result", position: nil, prize_money: 100)
      expect(helper.display_place(result, [ result ])).to eq("MC")
    end

    it "returns solo place number when one result at that position" do
      result = double("result", position: 1, prize_money: 2_000_000)
      expect(helper.display_place(result, [ result ])).to eq("1")
    end

    it "returns T plus position when multiple results share the same position" do
      r1 = double("r1", position: 3, prize_money: 500_000)
      r2 = double("r2", position: 3, prize_money: 500_000)
      r3 = double("r3", position: 3, prize_money: 500_000)
      results = [ r1, r2, r3 ]
      results.each do |r|
        expect(helper.display_place(r, results)).to eq("T3")
      end
    end

    it "does not count missed-cut results when determining ties" do
      r1 = double("r1", position: 2, prize_money: 1_000_000)
      r2_mc = double("r2_mc", position: 2, prize_money: 0)
      results = [ r1, r2_mc ]
      expect(helper.display_place(r1, results)).to eq("2")
      expect(helper.display_place(r2_mc, results)).to eq("MC")
    end
  end
end
