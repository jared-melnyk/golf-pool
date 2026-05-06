class EventMembership < ApplicationRecord
  ROLES = %w[commissioner player].freeze

  belongs_to :event
  belongs_to :user

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :event_id }

  def commissioner?
    role == "commissioner"
  end

  def player?
    role == "player"
  end
end
