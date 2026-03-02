# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pool, type: :model do
  let(:pool) { Pool.create!(name: "Test Pool") }
  let(:user) { User.create!(name: "User", email: "user@example.com", password: "password") }
  let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.from_now, ends_at: 4.days.from_now, external_id: "20") }
  let(:golfer) { Golfer.create!(name: "Golfer", external_id: "185") }

  before do
    PoolUser.create!(pool: pool, user: user)
    PoolTournament.create!(pool: pool, tournament: tournament)
  end

  describe "#standings" do
    it "returns array of [ user, total_points ] sorted by total descending" do
      pick = Pick.create!(user: user, tournament: tournament)
      PickGolfer.create!(pick: pick, golfer: golfer, slot: 1)
      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 1, prize_money: 500_000)

      standings = pool.standings
      expect(standings).to be_an(Array)
      expect(standings.size).to eq(1)
      expect(standings.first[0]).to eq(user)
      expect(standings.first[1]).to eq(500_000)
    end

    it "orders users by total points descending when multiple users have picks" do
      user2 = User.create!(name: "User 2", email: "user2@example.com", password: "password")
      PoolUser.create!(pool: pool, user: user2)
      golfer2 = Golfer.create!(name: "Golfer 2", external_id: "186")

      pick1 = Pick.create!(user: user, tournament: tournament)
      PickGolfer.create!(pick: pick1, golfer: golfer, slot: 1)
      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 1, prize_money: 300_000)

      pick2 = Pick.create!(user: user2, tournament: tournament)
      PickGolfer.create!(pick: pick2, golfer: golfer2, slot: 1)
      TournamentResult.create!(tournament: tournament, golfer: golfer2, position: 2, prize_money: 600_000)

      standings = pool.standings
      expect(standings.map { |u, _| u }).to eq([ user2, user ])
      expect(standings.map { |_, total| total }).to eq([ 600_000, 300_000 ])
    end

    it "includes an odds-based bonus on top of prize money when PoolTournamentOdds exist" do
      pick = Pick.create!(user: user, tournament: tournament)
      PickGolfer.create!(pick: pick, golfer: golfer, slot: 1)
      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 1, prize_money: 1_000_000)
      PoolTournamentOdds.create!(
        pool_tournament: PoolTournament.find_by(pool: pool, tournament: tournament),
        golfer: golfer,
        american_odds: 700,
        vendor: "fanduel",
        locked_at: Time.current
      )

      standings = pool.standings
      _user, total_points = standings.find { |u, _| u == user }
      expect(total_points).to be > 1_000_000
    end
  end

  describe "#start_date" do
    it "returns the starts_at of the first tournament by start time when pool has tournaments" do
      pool_with_dates = Pool.create!(name: "Pool with dates")
      early = Tournament.create!(name: "Early", starts_at: 1.week.from_now, ends_at: 2.weeks.from_now)
      late = Tournament.create!(name: "Late", starts_at: 2.weeks.from_now, ends_at: 3.weeks.from_now)
      PoolTournament.create!(pool: pool_with_dates, tournament: late)
      PoolTournament.create!(pool: pool_with_dates, tournament: early)
      expect(pool_with_dates.start_date).to eq(early.starts_at)
    end

    it "returns nil when pool has no tournaments" do
      empty_pool = Pool.create!(name: "Empty")
      expect(empty_pool.start_date).to be_nil
    end
  end

  describe "#total_points_for" do
    it "returns 0 when user has no pick for any pool tournament" do
      expect(pool.total_points_for(user)).to eq(0)
    end

    it "returns 0 when user has a pick but no tournament results for their golfers" do
      pick = Pick.create!(user: user, tournament: tournament)
      PickGolfer.create!(pick: pick, golfer: golfer, slot: 1)
      # No TournamentResult for this golfer
      expect(pool.total_points_for(user)).to eq(0)
    end

    it "returns sum of prize money for picked golfers when no locked odds" do
      pick = Pick.create!(user: user, tournament: tournament)
      PickGolfer.create!(pick: pick, golfer: golfer, slot: 1)
      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 1, prize_money: 750_000)
      expect(pool.total_points_for(user)).to eq(750_000)
    end

    it "adds odds bonus when PoolTournamentOdds exist and golfer makes the cut" do
      pick = Pick.create!(user: user, tournament: tournament)
      PickGolfer.create!(pick: pick, golfer: golfer, slot: 1)
      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 1, prize_money: 100_000)
      PoolTournamentOdds.create!(
        pool_tournament: PoolTournament.find_by(pool: pool, tournament: tournament),
        golfer: golfer,
        american_odds: 500,
        vendor: "fanduel",
        locked_at: Time.current
      )
      # bonus = 500 * 20 = 10_000 (only when made cut)
      expect(pool.total_points_for(user)).to eq(100_000 + 10_000)
    end

    it "gives no odds bonus when golfer misses the cut" do
      pick = Pick.create!(user: user, tournament: tournament)
      PickGolfer.create!(pick: pick, golfer: golfer, slot: 1)
      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 80, prize_money: 0)
      PoolTournamentOdds.create!(
        pool_tournament: PoolTournament.find_by(pool: pool, tournament: tournament),
        golfer: golfer,
        american_odds: 500,
        vendor: "fanduel",
        locked_at: Time.current
      )
      expect(pool.total_points_for(user)).to eq(0)
    end
  end
end
