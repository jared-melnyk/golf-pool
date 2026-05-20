class GameMembership < ApplicationRecord
  ROLES = %w[host cohost player].freeze

  belongs_to :game
  belongs_to :user

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :game_id }

  def host?
    role == "host"
  end

  def cohost?
    role == "cohost"
  end

  def player?
    role == "player"
  end

  def manager?
    host? || cohost?
  end
end
