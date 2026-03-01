class Pool < ApplicationRecord
  has_many :pool_tournaments, dependent: :destroy
  has_many :tournaments, through: :pool_tournaments
  has_many :pool_users, dependent: :destroy
  has_many :users, through: :pool_users

  before_validation :generate_token, on: :create

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true

  def to_param
    token
  end

  # Start date of the pool = start date of the first tournament (by starts_at).
  def start_date
    tournaments.order(:starts_at).limit(1).pick(:starts_at)
  end

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

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(16)
  end

  def odds_bonus(american_odds)
    american_odds.to_d.abs * 15
  end
end
