# frozen_string_literal: true

module Games
  module ScorecardHelper
    def scorecard_can_edit?(game, _event = nil)
      return false if game.completed?

      game.can_manage?(current_user) ||
        game.game_teams.joins(:game_team_players).where(game_team_players: { user_id: current_user.id }).exists?
    end

    # Any teammate (or manager) may enter gross scores for players on that team.
    def scorecard_can_edit_gross?(game, gtp)
      return false if game.completed? || gtp.blank?
      return true if game.can_manage?(current_user)

      GameTeamPlayer.joins(:game_team)
                    .where(game_teams: { id: gtp.game_team_id, game_id: game.id }, user_id: current_user.id)
                    .exists?
    end

    # Same team rule as gross — one scorer can manage 40 Score picks for the group.
    def scorecard_can_edit_forty_pick?(game, gtp)
      scorecard_can_edit_gross?(game, gtp)
    end

    def scorecard_focus_team(scorecard, game)
      return scorecard[:teams].first if scorecard[:teams].blank?

      owned = game.game_teams.joins(:game_team_players)
                  .where(game_team_players: { user_id: current_user.id })
                  .pluck(:id)
      scorecard[:teams].find { |t| owned.include?(t[:id]) } || scorecard[:teams].first
    end

    def scorecard_default_hole(scorecard, team_data)
      return 1 if team_data.blank?

      (1..18).find do |h|
        team_data[:players].any? do |player|
          player[:hole_scores].find { |s| s[:hole_number] == h }&.dig(:gross_score).blank?
        end
      end || 1
    end

    # Map player name → GameTeamPlayer for one group. Names are only unique within a team;
    # the same user may appear on multiple teams (separate GTP rows and DOM ids).
    def scorecard_gtps_for_team(game_team)
      game_team.game_team_players.index_by { |gtp| gtp.user.name }
    end

    def scorecard_team_data(scorecard, game_team)
      scorecard[:teams].find { |t| t[:id] == game_team.id }
    end

    # Leaderboard position: "1", "2", or "T2" when multiple teams share the same rank.
    def scorecard_display_rank(rank, leaderboard)
      return "—" if rank.nil?

      tied_at_rank = leaderboard.count { |row| row[:rank] == rank }
      tied_at_rank > 1 ? "T#{rank}" : rank.to_s
    end
  end
end
