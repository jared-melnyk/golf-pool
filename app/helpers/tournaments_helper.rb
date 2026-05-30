# frozen_string_literal: true

module TournamentsHelper
  # Returns the place string for a single result when displayed in a list of results.
  # - MC for missed cut / $0 (prize_money nil or zero)
  # - T + position when multiple results share the same position (tie)
  # - position otherwise
  def display_place(result, results)
    if result.position_display.present? &&
        TournamentResult::MISSED_CUT_POSITIONS.include?(result.position_display.upcase)
      return result.position_display
    end

    return "MC" if missed_cut?(result)

    position = result.position
    return result.position_display if position.nil? && result.position_display.present?
    return "MC" if position.nil?

    count_at_position = results.count do |r|
      !missed_cut?(r) && r.position == position
    end
    count_at_position > 1 ? "T#{position}" : position.to_s
  end

  def missed_cut?(result)
    result.missed_cut?
  end
end
