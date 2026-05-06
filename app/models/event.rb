class Event < ApplicationRecord
  STATUSES = %w[draft active completed].freeze

  has_many :event_memberships, dependent: :destroy
  has_many :users, through: :event_memberships
  has_many :rounds, dependent: :destroy

  before_validation :generate_token, on: :create

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  def to_param
    token
  end

  def commissioner?(user)
    user.present? && event_memberships.exists?(user_id: user.id, role: "commissioner")
  end

  def member?(user)
    user.present? && users.include?(user)
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(16)
  end
end
