class User < ApplicationRecord
  # Admin "Last visit": refresh at most this often while the user is active.
  LAST_SEEN_THROTTLE = 1.hour

  has_secure_password

  has_many :pool_users, dependent: :destroy
  has_many :pools, through: :pool_users
  has_many :picks, dependent: :destroy

  has_many :event_memberships, dependent: :destroy
  has_many :events, through: :event_memberships
  has_many :game_memberships, dependent: :destroy
  has_many :member_games, through: :game_memberships, source: :game
  has_many :game_team_players, dependent: :destroy
  has_many :hole_scores, through: :game_team_players

  before_validation :normalize_email

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :ghin_handicap_index,
            numericality: { greater_than_or_equal_to: -54, less_than_or_equal_to: 54 },
            allow_nil: true

  private

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end

  public

  def generate_password_reset_token
    raw_token = SecureRandom.urlsafe_base64(32)
    self.password_reset_token_digest = Digest::SHA256.hexdigest(raw_token)
    self.password_reset_sent_at = Time.current
    save!
    raw_token
  end

  def password_reset_token_valid?(raw_token)
    return false if password_reset_sent_at.blank?
    return false if password_reset_sent_at < 1.hour.ago
    return false if password_reset_token_digest.blank?

    digest = Digest::SHA256.hexdigest(raw_token.to_s)
    ActiveSupport::SecurityUtils.secure_compare(digest, password_reset_token_digest)
  end

  def clear_password_reset!
    self.password_reset_token_digest = nil
    self.password_reset_sent_at = nil
    update_columns(password_reset_token_digest: nil, password_reset_sent_at: nil)
  end

  def generate_remember_token
    raw_token = SecureRandom.urlsafe_base64(32)
    self.remember_token_digest = Digest::SHA256.hexdigest(raw_token)
    save!
    raw_token
  end

  def remember_token_valid?(raw_token)
    return false if remember_token_digest.blank?

    digest = Digest::SHA256.hexdigest(raw_token.to_s)
    ActiveSupport::SecurityUtils.secure_compare(digest, remember_token_digest)
  end

  def clear_remember_token!
    update_column(:remember_token_digest, nil)
  end

  # Updates admin "Last visit" without affecting auth/cookies.
  def touch_last_seen!
    return if last_login_at.present? && last_login_at > LAST_SEEN_THROTTLE.ago

    update_column(:last_login_at, Time.current)
  end
end
