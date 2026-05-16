class Game < ApplicationRecord
  GAME_TYPES = %w[best_ball forty_score].freeze

  belongs_to :event
  belongs_to :round
  has_many :game_teams, dependent: :destroy

  validates :game_type, presence: true, inclusion: { in: GAME_TYPES }

  def forty_score?
    game_type == "forty_score"
  end

  def playing_handicap_allowance_percent
    case game_type
    when "best_ball" then 85
    when "forty_score" then 100
    else 100
    end
  end
end
