class User < ApplicationRecord
  has_secure_password

  has_many :pool_users, dependent: :destroy
  has_many :pools, through: :pool_users
  has_many :picks, dependent: :destroy

  has_many :event_memberships, dependent: :destroy
  has_many :events, through: :event_memberships

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :ghin_handicap_index,
            numericality: { greater_than_or_equal_to: -54, less_than_or_equal_to: 54 },
            allow_nil: true

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
end
