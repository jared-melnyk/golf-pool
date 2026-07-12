# frozen_string_literal: true

# Ranks field teams for one format on a round; lists match-scoped games separately.
class RoundFormatStandings
  ScorecardClass = {
    "best_ball" => BestBallScorecard,
    "cha_cha_cha" => ChaChaChaScorecard,
    "forty_score" => FortyScoreScorecard,
    "vegas" => VegasScorecard
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
    teams = scorecard[:teams]

    if teams.empty?
      return [ {
        game_id: game.id,
        team_id: nil,
        team_name: game.name,
        metric_value: nil,
        live_label: "Set up teams",
        complete: false,
        game_token: game.token
      } ]
    end

    teams.map do |team|
      ranking_value =
        if @game_type == "forty_score" && team[:complete]
          team[:competition_vs_par]
        else
          team[:live_vs_par]
        end

      {
        game_id: game.id,
        team_id: team[:id],
        team_name: team[:name],
        metric_value: ranking_value,
        live_label: team[:live_label].presence || "—",
        complete: team[:complete] == true,
        game_token: game.token
      }
    end
  end

  def rank_field(results)
    with_score = results.select { |r| r[:metric_value].present? }
    without = results.reject { |r| r[:metric_value].present? }
    sorted = with_score.sort_by { |r| [ r[:metric_value], r[:team_name] ] }

    ranked = []
    sorted.each_with_index do |result, idx|
      rank = if idx.positive? && sorted[idx - 1][:metric_value] == result[:metric_value]
        ranked[idx - 1][:rank]
      else
        idx + 1
      end
      ranked << result.merge(rank: rank)
    end

    ranked + without.map { |r| r.merge(rank: nil) }
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
      teams = scorecard[:teams]
      best = teams.select { |t| t[:live_vs_par] }.min_by { |t| [ t[:live_vs_par], t[:name] ] }
      if best
        {
          label: "#{best[:name]} · #{best[:live_label]}",
          metric_value: best[:live_vs_par]
        }
      else
        { label: "In progress", metric_value: nil }
      end
    end

    {
      game_id: game.id,
      game_name: game.name,
      game_token: game.token,
      **summary
    }
  end
end
