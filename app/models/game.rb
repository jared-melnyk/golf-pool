class Game < ApplicationRecord
  GAME_TYPES = %w[best_ball].freeze

  belongs_to :event
  belongs_to :round
  has_many :game_teams, dependent: :destroy
  has_many :game_team_players, through: :game_teams

  validates :game_type, presence: true, inclusion: { in: GAME_TYPES }

  def playing_handicap_allowance_percent
    case game_type
    when "best_ball" then 85
    else 100
    end
  end
end
