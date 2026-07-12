class GameTeamPlayer < ApplicationRecord
  belongs_to :game_team
  belongs_to :user, optional: true
  belongs_to :game_guest, optional: true
  has_many :hole_scores, dependent: :destroy

  validates :user_id, uniqueness: { scope: :game_team_id }, allow_nil: true
  validates :game_guest_id, uniqueness: true, allow_nil: true
  validate :exactly_one_player_identity

  before_create :set_snapshot_handicap_index

  def display_name
    user&.name || game_guest&.name
  end

  private

  def exactly_one_player_identity
    if user_id.present? == game_guest_id.present?
      errors.add(:base, "must belong to exactly one of user or game guest")
    end
  end

  def set_snapshot_handicap_index
    self.snapshot_handicap_index ||= user&.ghin_handicap_index || game_guest&.handicap_index
  end
end
