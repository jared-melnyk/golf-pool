class Pool < ApplicationRecord
  belongs_to :creator, class_name: "User", optional: true

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

  def creator?(user)
    user.present? && creator_id == user.id
  end

  # Start date of the pool = start date of the first tournament (by starts_at).
  def start_date
    tournaments.order(:starts_at).limit(1).pick(:starts_at)
  end

  # Standings: total points per user from their picks in this pool's tournaments.
  # For each 4-golfer pick, only the top 3 golfer scores count.
  # Points per golfer = prize money + LongShot bonus (20 × American odds) only when the golfer makes the cut; otherwise 0 for that pick.
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
      pick = Pick.find_by(user: user, pool_tournament: pool_tournament)
      next 0.to_d unless pick

      golfer_scores = pick.golfers.map do |golfer|
        result = TournamentResult.find_by(tournament: tournament, golfer: golfer)
        base = result ? (result.prize_money.to_d || 0) : 0.to_d
        odds_row = PoolTournamentOdds.find_by(pool_tournament: pool_tournament, golfer: golfer)
        bonus = (odds_row && result&.made_cut?) ? tournament.capped_longshot_bonus(odds_row.american_odds) : 0.to_d
        base + bonus
      end

      golfer_scores.sort.reverse.first(3).sum
    end
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(16)
  end

  # LongShot bonus (uncapped): 20 × |american_odds|. Used when applying cap via tournament.
  def odds_bonus(american_odds)
    american_odds.to_d.abs * 20
  end

  # LongShot bonus capped at tournament's max_longshot_bonus (10% of prize pool).
  def capped_odds_bonus(tournament, american_odds)
    tournament.capped_longshot_bonus(american_odds)
  end
end
