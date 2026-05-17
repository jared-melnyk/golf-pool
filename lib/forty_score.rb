# frozen_string_literal: true

module FortyScore
  BASE_PICK_COUNT = 40
  BASE_PLAYER_COUNT = 4
  VALID_TEAM_SIZES = (3..4).freeze

  module_function

  def target_pick_count(player_count)
    (BASE_PICK_COUNT * player_count.to_f / BASE_PLAYER_COUNT).round
  end

  def competition_multiplier(player_count)
    BASE_PLAYER_COUNT.to_f / player_count
  end

  def competition_vs_par(actual_vs_par:, player_count:)
    return nil if actual_vs_par.nil?

    (actual_vs_par * competition_multiplier(player_count)).round
  end

  def valid_team_size?(player_count)
    VALID_TEAM_SIZES.cover?(player_count)
  end
end
