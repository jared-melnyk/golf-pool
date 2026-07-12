# frozen_string_literal: true

module GameScorecardBuilder
  extend ActiveSupport::Concern

  private

  def build_game_scorecard(game)
    preloaded = preload_game_for_scorecard(game)

    if game.forty_score?
      FortyScoreScorecard.new(preloaded).call
    elsif game.cha_cha_cha?
      ChaChaChaScorecard.new(preloaded).call
    elsif game.vegas?
      VegasScorecard.new(preloaded).call
    else
      BestBallScorecard.new(preloaded).call
    end
  end

  def preload_game_for_scorecard(game)
    ActiveRecord::Associations::Preloader.new(
      records: [ game ],
      associations: { game_teams: { game_team_players: [ :user, :game_guest, :hole_scores ] } }
    ).call
    game
  end

  def scorecard_team_for(scorecard, game_team)
    scorecard[:teams].find { |t| t[:id] == game_team.id }
  end
end
