class HoleScore < ApplicationRecord
  belongs_to :game_team_player

  validates :hole_number, inclusion: { in: 1..18 }
  validates :gross_score, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :hole_number, uniqueness: { scope: :game_team_player_id }

  validate :forty_pick_requires_gross, if: -> { forty_score_game? && included_in_forty_score? }
  validate :forty_pick_team_cap, if: -> { forty_score_game? && included_in_forty_score? }

  private

  def forty_score_game?
    game_team_player&.game_team&.game&.forty_score?
  end

  def forty_pick_requires_gross
    return if gross_score.present?

    errors.add(:included_in_forty_score, "requires a gross score for this hole")
  end

  def forty_pick_team_cap
    team = game_team_player.game_team
    player_count = team.game_team_players.count
    limit = FortyScore.target_pick_count(player_count)

    teammate_ids = GameTeamPlayer.where(game_team_id: team.id).pluck(:id)

    relation = HoleScore.where(game_team_player_id: teammate_ids, included_in_forty_score: true)
    relation = relation.where.not(id: id) if persisted?

    tally = relation.count + 1
    return if tally <= limit

    errors.add(:included_in_forty_score, "would exceed the #{limit}-count limit for this group")
  end
end
