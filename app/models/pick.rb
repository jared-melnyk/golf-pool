class Pick < ApplicationRecord
  belongs_to :user
  belongs_to :tournament
  has_many :pick_golfers, dependent: :destroy
  has_many :golfers, through: :pick_golfers

  validates :tournament_id, uniqueness: { scope: :user_id }

   validate :no_duplicate_golfers

  # Sum of prize money for this pick's golfers in this tournament (from tournament_results).
  def total_prize_money
    TournamentResult.where(tournament: tournament, golfer: golfers).sum(:prize_money)
  end

  private

  def no_duplicate_golfers
    ids = pick_golfers.reject(&:marked_for_destruction?).map(&:golfer_id).reject(&:blank?)
    return if ids.size == ids.uniq.size

    errors.add(:base, "You can't pick the same golfer more than once for a tournament.")
  end
end
