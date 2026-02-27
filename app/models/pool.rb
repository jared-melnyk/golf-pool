class Pool < ApplicationRecord
  has_many :pool_tournaments, dependent: :destroy
  has_many :tournaments, through: :pool_tournaments
  has_many :pool_users, dependent: :destroy
  has_many :users, through: :pool_users

  validates :name, presence: true

  # Standings: total points per user from their picks in this pool's tournaments.
  # Points = prize money + odds-based bonus where available.
  # Returns array of [ user, total_points ] sorted by total descending.
  def standings
    users
      .distinct
      .map { |user| [ user, total_points_for(user) ] }
      .sort_by { |_, total| -total }
  end

  def total_points_for(user)
    pool_tournaments.includes(:tournament).sum do |pool_tournament|
      tournament = pool_tournament.tournament
      pick = Pick.find_by(user: user, tournament: tournament)
      next 0.to_d unless pick

      pick.golfers.sum do |golfer|
        base = TournamentResult.where(tournament: tournament, golfer: golfer).sum(:prize_money).to_d
        odds_row = PoolTournamentOdds.find_by(pool_tournament: pool_tournament, golfer: golfer)
        bonus = odds_row ? odds_bonus(odds_row.american_odds) : 0.to_d
        base + bonus
      end
    end
  end

  private

  def odds_bonus(american_odds)
    american_odds.to_d.abs * 1000
  end
end
