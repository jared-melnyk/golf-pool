class GameTeam < ApplicationRecord
  belongs_to :game
  has_many :game_team_players, dependent: :destroy
  has_many :users, through: :game_team_players

  validates :name, presence: true
end
