class HoleScore < ApplicationRecord
  belongs_to :game_team_player

  validates :hole_number, inclusion: { in: 1..18 }
  validates :gross_score, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :hole_number, uniqueness: { scope: :game_team_player_id }
end
