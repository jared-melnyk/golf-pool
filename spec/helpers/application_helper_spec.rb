# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#at_max_longshot_bonus?" do
    it "returns true when uncapped bonus equals max_bonus" do
      # 500 * 20 = 10_000 >= 10_000
      expect(helper.at_max_longshot_bonus?(500, 10_000)).to be true
    end

    it "returns false when uncapped bonus is below max_bonus" do
      # 400 * 20 = 8_000 < 10_000
      expect(helper.at_max_longshot_bonus?(400, 10_000)).to be false
    end

    it "returns false when max_bonus is nil or zero" do
      expect(helper.at_max_longshot_bonus?(500, nil)).to be false
      expect(helper.at_max_longshot_bonus?(500, 0)).to be false
    end
  end

  describe "#golfer_name_with_odds" do
    it "appends asterisk when at max longshot bonus" do
      result = helper.golfer_name_with_odds("Scottie", 500, max_bonus: 10_000)
      expect(result).to include("*")
      expect(result).to eq("Scottie (+500)*")
    end

    it "does not append asterisk when max_bonus is not passed" do
      result = helper.golfer_name_with_odds("Scottie", 500)
      expect(result).not_to include("*")
      expect(result).to eq("Scottie (+500)")
    end

    it "does not append asterisk when not at cap" do
      result = helper.golfer_name_with_odds("Scottie", 400, max_bonus: 10_000)
      expect(result).not_to include("*")
    end
  end

  describe "#golfer_name_with_bonus" do
    it "shows capped bonus amount with label and asterisk at cap" do
      tournament = Tournament.new(total_prize_pool: 100_000, starts_at: Time.current)
      result = helper.golfer_name_with_bonus("Scottie", 500, tournament: tournament)

      expect(result).to eq("Scottie (Cut Made Bonus: $10,000)*")
    end

    it "shows uncapped bonus amount without asterisk when below cap" do
      tournament = Tournament.new(total_prize_pool: 1_000_000, starts_at: Time.current)
      result = helper.golfer_name_with_bonus("Scottie", 400, tournament: tournament)

      expect(result).to eq("Scottie (Cut Made Bonus: $8,000)")
    end

    it "returns name when odds are missing" do
      tournament = Tournament.new(total_prize_pool: 1_000_000, starts_at: Time.current)
      result = helper.golfer_name_with_bonus("Scottie", nil, tournament: tournament)

      expect(result).to eq("Scottie")
    end
  end
end
