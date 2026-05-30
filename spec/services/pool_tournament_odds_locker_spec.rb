# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolTournamentOddsLocker do
  include ActiveSupport::Testing::TimeHelpers

  let(:pool) { Pool.create!(name: "Test Pool") }
  let(:starts_at) { Time.zone.parse("2026-05-21 12:00:00") }
  let(:tournament) { Tournament.create!(name: "Byron Nelson", starts_at: starts_at, external_id: "27") }
  let(:pool_tournament) { PoolTournament.create!(pool: pool, tournament: tournament) }
  let!(:golfer) { Golfer.create!(name: "Jordan Spieth", external_id: "199") }
  let(:client) { instance_double(BallDontLie::Client) }
  let(:lock_time) { Time.zone.parse("2026-05-20 23:45:00") }

  let(:future_row) do
    {
      "market_type" => "tournament_winner",
      "player" => { "id" => 199, "display_name" => "Jordan Spieth" },
      "american_odds" => 3500,
      "vendor" => "draftkings"
    }
  end

  before do
    allow(BallDontLie::Client).to receive(:new).and_return(client)
    allow(client).to receive(:fetch_all_futures).and_return([ future_row ])
  end

  it "creates odds rows before picks lock" do
    travel_to(starts_at - 2.days) do
      expect {
        described_class.new(pool_tournament: pool_tournament, locked_at: lock_time).call
      }.to change(PoolTournamentOdds, :count).by(1)

      odds = PoolTournamentOdds.last
      expect(odds.american_odds).to eq(3500)
      expect(odds.locked_at).to eq(lock_time)
      expect(pool_tournament.reload.odds_locked_at).to eq(lock_time)
    end
  end

  it "refreshes existing odds while picks are still open" do
    travel_to(starts_at - 2.days) do
      PoolTournamentOdds.create!(
        pool_tournament: pool_tournament,
        golfer: golfer,
        american_odds: 2800,
        vendor: "draftkings",
        locked_at: 1.hour.ago
      )
      pool_tournament.update_column(:odds_locked_at, 1.hour.ago)

      result = described_class.new(pool_tournament: pool_tournament, locked_at: lock_time).call

      expect(result.created).to eq(0)
      expect(result.updated).to eq(1)
      expect(PoolTournamentOdds.find_by!(pool_tournament: pool_tournament, golfer: golfer).american_odds).to eq(3500)
      expect(pool_tournament.reload.odds_locked_at).to eq(lock_time)
    end
  end

  it "allows manual refresh after picks lock when force is true" do
    travel_to(starts_at + 1.hour) do
      PoolTournamentOdds.create!(
        pool_tournament: pool_tournament,
        golfer: golfer,
        american_odds: 2800,
        vendor: "draftkings",
        locked_at: lock_time
      )

      described_class.new(pool_tournament: pool_tournament, force: true).call

      expect(PoolTournamentOdds.find_by!(pool_tournament: pool_tournament, golfer: golfer).american_odds).to eq(3500)
    end
  end

  it "refuses to lock after picks lock without force" do
    travel_to(starts_at + 1.hour) do
      expect {
        described_class.new(pool_tournament: pool_tournament).call
      }.to raise_error(PoolTournamentOddsLocker::LockNotAllowedError, /Picks are locked/)
    end
  end

  it "ignores non tournament_winner markets" do
    travel_to(starts_at - 2.days) do
      allow(client).to receive(:fetch_all_futures).and_return(
        [ future_row.merge("market_type" => "make_the_cut") ]
      )

      expect {
        described_class.new(pool_tournament: pool_tournament).call
      }.not_to change(PoolTournamentOdds, :count)
    end
  end
end
