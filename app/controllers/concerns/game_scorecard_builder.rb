# frozen_string_literal: true

module GameScorecardBuilder
  extend ActiveSupport::Concern

  private

  def build_game_scorecard(game)
    preloaded = preload_game_for_scorecard(game)

    if game.forty_score?
      FortyScoreScorecard.new(preloaded).call
    else
      BestBallScorecard.new(preloaded).call
    end
  end

  def preload_game_for_scorecard(game)
    ActiveRecord::Associations::Preloader.new(
      records: [ game ],
      associations: { game_teams: { game_team_players: [ :user, :hole_scores ] } }
    ).call
    game
  end

  def scorecard_team_for(scorecard, game_team)
    scorecard[:teams].find { |t| t[:id] == game_team.id }
  end

  def scorecard_gtps_by_name(game, scorecard)
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
end
