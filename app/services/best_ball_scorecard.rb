# Computes a Best Ball scorecard for a given Game.
# Returns a structured hash:
#   {
#     teams: [
#       {
#         id: ..., name: ..., total_net_strokes: ...,
#         players: [ { name:, course_handicap:, playing_handicap:, hole_scores: [{ hole_number:, gross_score:, net_score:, strokes_received: }] } ],
#         hole_scores: [ { hole_number:, best_ball_net: } ]
#       }
#     ],
#     leaderboard: [ { rank:, team_name:, total_net_strokes: } ]
#   }
class BestBallScorecard
  def initialize(game)
    @game = game
    @round = game.round
    @allowance = game.playing_handicap_allowance_percent
  end

  def call
    teams_data = @game.game_teams.includes(game_team_players: [ :user, :hole_scores ]).map do |team|
      build_team(team)
    end

    { teams: teams_data, leaderboard: build_leaderboard(teams_data) }
  end

  private

  def build_team(team)
    players_data = team.game_team_players.map { |gtp| build_player(gtp) }

    hole_scores = (1..18).map do |h|
      nets = players_data.filter_map { |p| p[:hole_scores].find { |s| s[:hole_number] == h }&.dig(:net_score) }
      { hole_number: h, best_ball_net: nets.any? ? nets.min : nil }
    end

    nets = hole_scores.map { |s| s[:best_ball_net] }
    total = nets.any?(&:nil?) ? nil : nets.sum

    { id: team.id, name: team.name, players: players_data, hole_scores: hole_scores, total_net_strokes: total }
  end

  def build_player(gtp)
    hi = gtp.snapshot_handicap_index.to_f
    ch = course_handicap(hi)
    ph = playing_handicap(ch)
    scores_by_hole = gtp.hole_scores.index_by(&:hole_number)

    hole_scores = (1..18).map do |h|
      strokes = strokes_on_hole(ph, h)
      gross = scores_by_hole[h]&.gross_score
      net = gross ? gross - strokes : nil
      { hole_number: h, gross_score: gross, net_score: net, strokes_received: strokes }
    end

    {
      name: gtp.user.name,
      course_handicap: ch,
      playing_handicap: ph,
      hole_scores: hole_scores
    }
  end

  # WHS formula: HI × (slope ÷ 113) + (course_rating − par)
  def course_handicap(hi)
    slope = @round.slope_rating.to_f
    rating = @round.course_rating.to_f
    par = @round.par_total.to_f
    (hi * (slope / 113.0) + (rating - par)).round
  end

  def playing_handicap(ch)
    (ch * @allowance / 100.0).round
  end

  # Returns number of strokes a player with playing_handicap receives on a given hole.
  # stroke_indices array is 0-indexed (hole 1 = index 0); values are 1–18 (1 = hardest).
  # A player with PH strokes gets a stroke on the PH hardest holes.
  def strokes_on_hole(playing_handicap, hole_number)
    return 0 if playing_handicap <= 0

    si = @round.hole_handicaps[hole_number - 1]
    base = playing_handicap / 18
    return base if si.nil?

    remainder = playing_handicap % 18
    base + (si <= remainder ? 1 : 0)
  end

  def build_leaderboard(teams_data)
    teams_with_totals = teams_data.map { |t| { team_name: t[:name], total_net_strokes: t[:total_net_strokes] } }
    complete = teams_with_totals.select { |t| t[:total_net_strokes].present? }
    incomplete = teams_with_totals.reject { |t| t[:total_net_strokes].present? }
    sorted = complete.sort_by { |t| [ t[:total_net_strokes], t[:team_name] ] }

    # Ordinal ranking (1-2-2-4 style); display adds T prefix only for ties.
    ranked = []
    sorted.each_with_index do |team, idx|
      if idx.positive? && sorted[idx - 1][:total_net_strokes] == team[:total_net_strokes]
        ranked << team.merge(rank: ranked[idx - 1][:rank])
      else
        ranked << team.merge(rank: idx + 1)
      end
    end
    ranked + incomplete.map { |t| t.merge(rank: nil) }
  end
end
