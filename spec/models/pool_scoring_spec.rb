require "rails_helper"

RSpec.describe Pool, type: :model do
  describe "#standings with odds bonus" do
    let(:pool) { Pool.create!(name: "Odds Pool") }
    let(:user) { User.create!(name: "User", email: "user@example.com", password: "password") }
    let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.from_now, ends_at: 4.days.from_now, external_id: "20") }
    let(:golfer) { Golfer.create!(name: "Golfer", external_id: "185") }

    before do
      PoolUser.create!(pool: pool, user: user)
      PoolTournament.create!(pool: pool, tournament: tournament)

      pick = Pick.create!(user: user, tournament: tournament)
      PickGolfer.create!(pick: pick, golfer: golfer, slot: 1)

      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 1, prize_money: 1_000_000)

      # Locked odds snapshot: american_odds = +700
      PoolTournamentOdds.create!(
        pool_tournament: PoolTournament.find_by(pool: pool, tournament: tournament),
        golfer: golfer,
        american_odds: 700,
        vendor: "fanduel",
        locked_at: Time.current
      )
    end

    it "includes an odds-based bonus on top of prize money" do
      standings = pool.standings
      user_entry = standings.find { |u, _| u == user }
      expect(user_entry).not_to be_nil

      _user, total_points = user_entry

      # Base prize money
      expect(total_points).to be > 1_000_000
    end
  end
end

