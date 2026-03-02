class TournamentResult < ApplicationRecord
  belongs_to :tournament
  belongs_to :golfer

  validates :tournament_id, uniqueness: { scope: :golfer_id }
  validates :prize_money, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def made_cut?
    prize_money.present? && prize_money.to_d.positive?
  end
end
