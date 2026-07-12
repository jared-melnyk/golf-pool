# frozen_string_literal: true

# Ranks field teams for one format on a round; lists match-scoped games separately.
class RoundFormatStandings
  ScorecardClass = {
    "best_ball" => BestBallScorecard,
    "cha_cha_cha" => ChaChaChaScorecard,
    "forty_score" => FortyScoreScorecard,
    "vegas" => VegasScorecard
  }.freeze

  FieldMetric = {
    "best_ball" => :total_net_strokes,
    "cha_cha_cha" => :total_net_strokes,
    "forty_score" => :competition_vs_par
  }.freeze

  def initialize(round:, game_type:)
    @round = round
    @game_type = game_type.to_s
  end

  def call
    games = @round.games.where(game_type: @game_type).includes(game_teams: { game_team_players: :hole_scores }).order(:created_at)

    field_rows = []
    matches = []

    games.each do |game|
      if game.vegas? || game.match_scope?
        matches << match_summary(game)
      else
        field_rows.concat(field_results_for(game))
      end
    end

    { field: rank_field(field_rows), matches: matches }
  end

  private

  def field_results_for(game)
    scorecard = ScorecardClass.fetch(@game_type).new(game).call
    metric_key = FieldMetric.fetch(@game_type)

    scorecard[:teams].map do |team|
      value = team[metric_key]
      TeamResult.new(
        game_id: game.id,
        team_id: team[:id],
        team_name: team[:name],
        round_id: game.round_id,
        event_id: game.event_id,
        game_type: @game_type,
        scope: :field,
        metric_key: metric_key,
        metric_value: value,
        complete: value.present?
      )
    end
  end

  def rank_field(results)
    complete = results.select(&:complete).sort_by { |r| [ r.metric_value, r.team_name ] }
    incomplete = results.reject(&:complete)

    ranked = []
    complete.each_with_index do |result, idx|
      rank = if idx.positive? && complete[idx - 1].metric_value == result.metric_value
        ranked[idx - 1][:rank]
      else
        idx + 1
      end
      ranked << result_hash(result, rank)
    end

    ranked + incomplete.map { |r| result_hash(r, nil) }
  end

  def result_hash(result, rank)
    {
      rank: rank,
      team_name: result.team_name,
      game_id: result.game_id,
      team_id: result.team_id,
      metric_key: result.metric_key,
      metric_value: result.metric_value,
      scope: result.scope,
      complete: result.complete,
      game_token: games_by_id[result.game_id]&.token
    }
  end

  def match_summary(game)
    if game.vegas? && game.game_teams.size < 2
      return {
        game_id: game.id,
        game_name: game.name,
        game_token: game.token,
        label: "Set up teams",
        metric_value: nil
      }
    end

    scorecard = ScorecardClass.fetch(@game_type).new(game).call
    summary = if game.vegas?
      wash = scorecard[:wash]
      { label: wash[:label], metric_value: wash[:margin] }
    else
      leaders = scorecard[:leaderboard]
      top = leaders.find { |row| row[:rank] == 1 }
      {
        label: top ? "#{top[:team_name]} leads" : "In progress",
        metric_value: top&.dig(:total_net_strokes)
      }
    end

    {
      game_id: game.id,
      game_name: game.name,
      game_token: game.token,
      **summary
    }
  end

  def games_by_id
    @games_by_id ||= @round.games.index_by(&:id)
  end
end
