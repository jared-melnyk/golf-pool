# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayoutCurveBuilder do
  describe ".empirical_payload_for" do
    it "builds position shares from prior-year paid results" do
      prior = Tournament.create!(
        name: "Charles Schwab Challenge",
        starts_at: Time.zone.parse("2025-05-20"),
        total_prize_pool: 10_000_000
      )
      g1 = Golfer.create!(name: "A", external_id: "p1")
      g2 = Golfer.create!(name: "B", external_id: "p2")
      TournamentResult.create!(tournament: prior, golfer: g1, position: 1, prize_money: 1_800_000)
      TournamentResult.create!(tournament: prior, golfer: g2, position: 2, prize_money: 1_090_000)
      48.times do |i|
        g = Golfer.create!(name: "F#{i}", external_id: "pf#{i}")
        TournamentResult.create!(tournament: prior, golfer: g, position: i + 3, prize_money: 10_000)
      end

      payload = described_class.empirical_payload_for(prior)

      expect(payload["shares"]["1"]).to eq("0.18")
      expect(payload["shares"]["2"]).to eq("0.109")
      expect(payload["metadata"]["prior_tournament_id"]).to eq(prior.id)
    end

    it "returns nil when fewer than 50 paid positions exist" do
      prior = Tournament.create!(name: "Small Event", starts_at: 1.year.ago, total_prize_pool: 1_000_000)
      g = Golfer.create!(name: "Only", external_id: "only")
      TournamentResult.create!(tournament: prior, golfer: g, position: 1, prize_money: 100_000)

      expect(described_class.empirical_payload_for(prior)).to be_nil
    end
  end

  describe ".build_empirical!" do
    it "persists empirical curve on the current tournament" do
      prior = Tournament.create!(
        name: "Charles Schwab Challenge",
        starts_at: Time.zone.parse("2025-05-20"),
        total_prize_pool: 10_000_000
      )
      50.times do |i|
        g = Golfer.create!(name: "F#{i}", external_id: "b#{i}")
        TournamentResult.create!(tournament: prior, golfer: g, position: i + 1, prize_money: 100_000 + i)
      end

      current = Tournament.create!(
        name: "Charles Schwab Challenge",
        starts_at: Time.zone.parse("2026-05-20"),
        total_prize_pool: 10_000_000
      )

      described_class.build_empirical!(current)
      current.reload

      expect(current.payout_curve_source).to eq("empirical")
      expect(current.payout_curve["shares"]).to be_present
    end
  end
end
