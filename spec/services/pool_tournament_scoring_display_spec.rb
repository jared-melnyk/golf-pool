# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolTournamentScoringDisplay do
  let(:creator) { User.create!(email: "c@example.com", name: "C", password: "password") }
  let(:pool) { Pool.create!(name: "P", creator: creator) }
  let(:tournament) { Tournament.create!(name: "Live", starts_at: 1.day.ago, external_id: "28", total_prize_pool: 10_000_000) }
  let(:pool_tournament) { PoolTournament.create!(pool: pool, tournament: tournament) }
  let(:golfer) { Golfer.create!(name: "G", external_id: "100") }
  let(:odds_row) do
    PoolTournamentOdds.create!(
      pool_tournament: pool_tournament,
      golfer: golfer,
      american_odds: 500,
      vendor: "dk",
      locked_at: Time.current
    )
  end
  let(:results_by_golfer) { {} }
  let(:odds_by_golfer) { { golfer.id => odds_row } }

  def build_display(round_results: {}, current_round: 2)
    described_class.new(
      tournament: tournament,
      results_by_golfer: results_by_golfer,
      odds_by_golfer: odds_by_golfer,
      round_results: round_results,
      current_round: current_round
    )
  end

  describe "#bonus_for" do
    it "returns :mc when cut posted and result is CUT" do
      TournamentResult.create!(tournament: tournament, golfer: golfer, position_display: "CUT")
      results = { golfer.id => tournament.tournament_results.find_by(golfer: golfer) }
      display = described_class.new(
        tournament: tournament,
        results_by_golfer: results,
        odds_by_golfer: odds_by_golfer,
        round_results: {},
        current_round: 2
      )
      expect(display.bonus_for(golfer)).to eq(:mc)
    end

    it "returns capped bonus when cut posted and made cut" do
      other = Golfer.create!(name: "Other", external_id: "999")
      TournamentResult.create!(tournament: tournament, golfer: other, position_display: "CUT")
      results = { golfer.id => TournamentResult.create!(tournament: tournament, golfer: golfer, position_display: "T18") }
      display = described_class.new(
        tournament: tournament,
        results_by_golfer: results,
        odds_by_golfer: odds_by_golfer,
        round_results: {},
        current_round: 2
      )
      expect(display.bonus_for(golfer)).to eq(10_000.to_d)
    end
  end

  describe "#show_counted_dropped_badges?" do
    it "returns false before cut" do
      expect(build_display.show_counted_dropped_badges?).to be false
    end

    it "returns true when cut posted" do
      TournamentResult.create!(tournament: tournament, golfer: golfer, position_display: "CUT")
      expect(build_display.show_counted_dropped_badges?).to be true
    end
  end

  describe "#total_earnings_for" do
    it "returns 0 for MC after cut" do
      results = { golfer.id => TournamentResult.create!(tournament: tournament, golfer: golfer, position_display: "CUT") }
      display = described_class.new(
        tournament: tournament,
        results_by_golfer: results,
        odds_by_golfer: odds_by_golfer,
        round_results: {},
        current_round: 2
      )
      expect(display.total_earnings_for(golfer)).to eq(0.to_d)
    end
  end
end
