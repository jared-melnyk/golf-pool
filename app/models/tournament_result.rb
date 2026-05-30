class TournamentResult < ApplicationRecord
  MISSED_CUT_POSITIONS = %w[CUT WD DQ MDF].freeze

  belongs_to :tournament
  belongs_to :golfer

  validates :tournament_id, uniqueness: { scope: :golfer_id }
  validates :prize_money, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def missed_cut?
    if position_display.present?
      return MISSED_CUT_POSITIONS.include?(position_display.to_s.upcase)
    end

    prize_money.nil? || prize_money.to_d.zero?
  end

  def made_cut_for_bonus?
    !missed_cut?
  end

  def made_cut?
    made_cut_for_bonus?
  end

  def self.assign_leaderboard_from_api(result, api_row)
    display = api_row["position"].presence&.to_s
    result.position_display = display
    result.position = parse_position_numeric(api_row["position_numeric"], display)
    result
  end

  def self.parse_position_numeric(position_numeric, display)
    return nil if display.present? && MISSED_CUT_POSITIONS.include?(display.upcase)
    return position_numeric.to_i if position_numeric.present?
    return display.to_i if display.present? && display.match?(/\A\d+\z/)

    nil
  end
end
