# frozen_string_literal: true

require "rails_helper"

RSpec.describe LiveScoreFormatting do
  describe ".thru_label" do
    it "formats vs par with holes played" do
      expect(described_class.thru_label(5, 7)).to eq("+5 (7)")
      expect(described_class.thru_label(-2, 6)).to eq("-2 (6)")
      expect(described_class.thru_label(0, 3)).to eq("E (3)")
    end

    it "is nil when no holes" do
      expect(described_class.thru_label(0, 0)).to be_nil
    end
  end

  describe ".picks_label" do
    it "formats vs par with pick progress" do
      expect(described_class.picks_label(-3, 14, 40)).to eq("-3 (14/40)")
    end
  end
end
