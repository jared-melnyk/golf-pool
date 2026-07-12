class GameGuest < ApplicationRecord
  belongs_to :game
  has_many :game_team_players, dependent: :destroy

  validates :name, presence: true
  validates :handicap_index,
            presence: true,
            numericality: { greater_than_or_equal_to: -54, less_than_or_equal_to: 54 }
end
