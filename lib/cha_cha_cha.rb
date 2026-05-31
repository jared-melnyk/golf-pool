# frozen_string_literal: true

module ChaChaCha
  VALID_TEAM_SIZES = (3..4).freeze

  module_function

  def scores_to_count(hole_number)
    ((hole_number - 1) % 3) + 1
  end

  def valid_team_size?(player_count)
    VALID_TEAM_SIZES.cover?(player_count)
  end
end
