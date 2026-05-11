class GameTeamPlayer < ApplicationRecord
  belongs_to :game_team
  belongs_to :user
  has_many :hole_scores, dependent: :destroy

  validates :user_id, uniqueness: { scope: :game_team_id }

  before_create :set_snapshot_handicap_index

  private

  def set_snapshot_handicap_index
    self.snapshot_handicap_index ||= user.ghin_handicap_index
  end
end
