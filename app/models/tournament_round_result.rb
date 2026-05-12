class TournamentRoundResult < ApplicationRecord
  belongs_to :tournament
  belongs_to :golfer

  validates :round_number, presence: true,
                           inclusion: { in: 1..4, message: "must be between 1 and 4" },
                           uniqueness: { scope: [ :tournament_id, :golfer_id ] }

  def par_relative
    return nil if score_to_par.nil?
    v = score_to_par.to_i
    return "E" if v.zero?
    v.positive? ? "+#{v}" : v.to_s
  end
end
