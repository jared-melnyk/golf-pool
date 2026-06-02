# frozen_string_literal: true

class ProjectedPrizeMoney
  def initialize(tournament:, curve:)
    @tournament = tournament
    @curve = curve
  end

  def for_result(result)
    return nil if @curve.nil? || result.nil?
    return 0.to_d if result.missed_cut?

    position_numeric = result.position
    position_display = result.position_display
    return nil if position_numeric.blank? && position_display.blank?

    amount = @curve.amount_for(
      position_numeric,
      purse: @tournament.effective_prize_pool,
      position_display: position_display
    )
    amount&.to_d
  end
end
