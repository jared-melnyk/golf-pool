# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayoutCurve do
  let(:shares) do
    {
      "1" => "0.18",
      "2" => "0.109",
      "5" => "0.041"
    }
  end
  let(:curve) { described_class.new(shares: shares) }
  let(:purse) { BigDecimal("10000000") }

  describe "#amount_for" do
    it "returns purse times share for a finishing position" do
      expect(curve.amount_for(1, purse: purse)).to eq(1_800_000.to_d)
    end

    it "averages tie positions via T-display parsing" do
      expect(curve.amount_for(nil, purse: purse, position_display: "T5")).to eq(410_000.to_d)
    end

    it "returns zero-equivalent share for missed cut display" do
      expect(curve.amount_for(50, purse: purse, position_display: "CUT")).to be_nil
    end

    it "keeps higher positions monotonically lower than winner" do
      first = curve.amount_for(1, purse: purse)
      second = curve.amount_for(2, purse: purse)
      expect(second).to be < first
    end
  end
end
