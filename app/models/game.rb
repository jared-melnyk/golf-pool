class Game < ApplicationRecord
  GAME_TYPES = %w[best_ball forty_score cha_cha_cha vegas].freeze
  STATUSES = %w[draft active completed].freeze

  belongs_to :event, optional: true
  belongs_to :round, optional: true
  belongs_to :creator, class_name: "User"
  has_many :game_memberships, dependent: :destroy
  has_many :members, through: :game_memberships, source: :user
  has_many :game_teams, dependent: :destroy

  before_validation :generate_token, on: :create

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :game_type, inclusion: { in: GAME_TYPES }, allow_nil: true
  validate :active_requires_round_and_game_type
  validate :round_event_matches_game_event

  def to_param
    token
  end

  def completed?
    status == "completed"
  end

  def draft?
    status == "draft"
  end

  def active?
    status == "active"
  end

  def ad_hoc?
    event_id.nil?
  end

  def self.type_label(game_type)
    case game_type
    when "cha_cha_cha" then "Cha-Cha-Cha (1-2-3)"
    else game_type.to_s.tr("_", " ").titleize
    end
  end

  def suggested_name
    return nil unless round && game_type.present?

    "#{self.class.type_label(game_type)} · #{round.course_name} · #{round.played_on.strftime('%-b %-d')}"
  end

  def host?(user)
    user.present? && game_memberships.exists?(user_id: user.id, role: "host")
  end

  def cohost?(user)
    user.present? && game_memberships.exists?(user_id: user.id, role: "cohost")
  end

  def manager?(user)
    host?(user) || cohost?(user)
  end

  def member?(user)
    return false if user.blank?
    return true if game_memberships.exists?(user_id: user.id)
    return event.member?(user) if event.present?

    game_teams.joins(:game_team_players).exists?(game_team_players: { user_id: user.id })
  end

  def can_manage?(user)
    return event.commissioner?(user) if event.present?

    manager?(user)
  end

  def roster_users
    ad_hoc? ? members.order(:name) : event.users.order(:name)
  end

  def self.visible_to(user)
    from_memberships = GameMembership.where(user_id: user.id).select(:game_id)
    from_events = where(event_id: EventMembership.where(user_id: user.id).select(:event_id)).select(:id)
    from_teams = joins(game_teams: :game_team_players).where(game_team_players: { user_id: user.id }).select(:id)

    where(id: from_memberships).or(where(id: from_events)).or(where(id: from_teams)).distinct
  end

  def forty_score?
    game_type == "forty_score"
  end

  def cha_cha_cha?
    game_type == "cha_cha_cha"
  end

  def vegas?
    game_type == "vegas"
  end

  def playing_handicap_allowance_percent
    case game_type
    when "best_ball", "cha_cha_cha" then 85
    when "forty_score", "vegas" then 100
    else 100
    end
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(16)
  end

  def active_requires_round_and_game_type
    return unless status == "active" || status == "completed"

    errors.add(:base, "Round is required to activate game") if round.blank?
    errors.add(:base, "Game type is required to activate game") if game_type.blank?
  end

  def round_event_matches_game_event
    return if round.blank? || event_id.blank?

    errors.add(:round, "must belong to the same event") if round.event_id != event_id
  end
end
