require "rails_helper"

RSpec.describe TournamentRoundResult, type: :model do
  let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.ago, ends_at: 1.day.from_now, external_id: "20") }
  let(:golfer) { Golfer.create!(name: "Scottie", external_id: "185") }

  describe "validations" do
    it "requires tournament, golfer, and round_number" do
      trr = described_class.new
      expect(trr).not_to be_valid
      expect(trr.errors[:tournament]).to be_present
      expect(trr.errors[:golfer]).to be_present
      expect(trr.errors[:round_number]).to be_present
    end

    it "validates round_number is between 1 and 4" do
      [ 0, 5, -1 ].each do |bad|
        trr = described_class.new(tournament: tournament, golfer: golfer, round_number: bad)
        expect(trr).not_to be_valid, "expected round_number=#{bad} to be invalid"
        expect(trr.errors[:round_number]).to be_present
      end
      (1..4).each do |good|
        trr = described_class.new(tournament: tournament, golfer: golfer, round_number: good)
        expect(trr).to be_valid, "expected round_number=#{good} to be valid"
      end
    end

    it "enforces uniqueness on (tournament_id, golfer_id, round_number)" do
      described_class.create!(tournament: tournament, golfer: golfer, round_number: 1)
      dup = described_class.new(tournament: tournament, golfer: golfer, round_number: 1)
      expect(dup).not_to be_valid
      expect(dup.errors[:round_number]).to be_present
    end
  end

  describe "#par_relative" do
    it "formats score_to_par as +N / -N / E / nil" do
      expect(described_class.new(score_to_par: 0).par_relative).to eq("E")
      expect(described_class.new(score_to_par: 3).par_relative).to eq("+3")
      expect(described_class.new(score_to_par: -2).par_relative).to eq("-2")
      expect(described_class.new(score_to_par: nil).par_relative).to be_nil
    end
  end
end
