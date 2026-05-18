# frozen_string_literal: true

module Games
  module ScorecardHelper
    def scorecard_can_edit?(game, event)
      return false if game.submitted

      event.commissioner?(current_user) ||
        game.game_teams.joins(:game_team_players).where(game_team_players: { user_id: current_user.id }).exists?
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
