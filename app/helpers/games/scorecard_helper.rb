# frozen_string_literal: true

module Games
  module ScorecardHelper
    def scorecard_can_edit?(game, event)
      return false if game.submitted

      event.commissioner?(current_user) ||
        game.game_teams.joins(:game_team_players).where(game_team_players: { user_id: current_user.id }).exists?
    end

    def scorecard_gtp_by_name(game, scorecard)
      gtp_by_name = {}
      scorecard[:teams].each do |team|
        team[:players].each do |player|
          next if gtp_by_name.key?(player[:name])

          gtp_by_name[player[:name]] = GameTeamPlayer
            .joins(:game_team, :user)
            .where(game_teams: { game_id: game.id })
            .where(users: { name: player[:name] })
            .first
        end
      end
      gtp_by_name
    end

    def scorecard_team_data(scorecard, game_team)
      scorecard[:teams].find { |t| t[:id] == game_team.id }
    end
  end
end
