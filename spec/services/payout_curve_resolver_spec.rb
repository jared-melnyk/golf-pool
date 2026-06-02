# frozen_string_literal: true

require "rails_helper"

RSpec.describe PayoutCurveResolver do
  def seed_prior_year_paid_results(name:, year:, count: 50)
    prior = Tournament.create!(
      name: name,
      starts_at: Time.zone.parse("#{year}-05-20"),
      total_prize_pool: 10_000_000
    )
    count.times do |i|
      g = Golfer.create!(name: "#{name} #{i}", external_id: "#{year}-#{i}")
      TournamentResult.create!(tournament: prior, golfer: g, position: i + 1, prize_money: 100_000)
    end
    prior
  end

  describe "#resolve_and_persist!" do
    it "uses empirical curve when prior-year paid results exist" do
      seed_prior_year_paid_results(name: "Charles Schwab Challenge", year: 2025)
      current = Tournament.create!(
        name: "Charles Schwab Challenge",
        starts_at: Time.zone.parse("2026-05-20"),
        total_prize_pool: 10_000_000
      )

      outcome = described_class.new(current).resolve_and_persist!
      current.reload

      expect(outcome).to eq(:empirical)
      expect(current.payout_curve_source).to eq("empirical")
      expect(current.payout_curve["shares"]).to be_present
    end

    it "falls back to static standard_cut when empirical data is missing" do
      current = Tournament.create!(
        name: "Random Regional Open",
        starts_at: Time.zone.parse("2026-03-01"),
        total_prize_pool: 8_000_000
      )

      outcome = described_class.new(current).resolve_and_persist!
      current.reload

      expect(outcome).to eq(:static)
      expect(current.payout_curve_source).to eq("static")
      expect(current.payout_curve["metadata"]["profile_id"]).to eq("standard_cut")
    end

    it "uses us_open static profile for U.S. Open" do
      current = Tournament.create!(
        name: "U.S. Open",
        starts_at: Time.zone.parse("2026-06-15"),
        total_prize_pool: 21_500_000
      )

      described_class.new(current).resolve_and_persist!
      current.reload

      expect(current.payout_curve_source).to eq("static")
      expect(current.payout_curve["metadata"]["profile_id"]).to eq("us_open")
      expect(current.payout_curve["shares"]["1"].to_d).to eq(0.20.to_d)
    end

    it "uses open_championship static profile for The Open Championship" do
      current = Tournament.create!(
        name: "The Open Championship",
        starts_at: Time.zone.parse("2026-07-15"),
        total_prize_pool: 17_000_000
      )

      described_class.new(current).resolve_and_persist!
      current.reload

      expect(current.payout_curve_source).to eq("static")
      expect(current.payout_curve["metadata"]["profile_id"]).to eq("open_championship")
    end

    it "persists hidden for suppressed events like Tour Championship" do
      current = Tournament.create!(
        name: "Tour Championship",
        starts_at: Time.zone.parse("2026-08-20"),
        total_prize_pool: 100_000_000
      )

      outcome = described_class.new(current).resolve_and_persist!
      current.reload

      expect(outcome).to eq(:hidden)
      expect(current.payout_curve_source).to eq("hidden")
      expect(current.payout_curve).to be_nil
    end
  end
end
