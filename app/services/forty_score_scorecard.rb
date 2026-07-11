# frozen_string_literal: true

# Forty Score per https://www.thefriedegg.com/articles/how-to-play-golf-game-40-score —
# each group selects counted net strokes (30 for threesomes, 40 for foursomes);
# leaderboard ranks on competition vs par (40-hole equivalent for threesomes).
#
# Returns {
#   teams: [
#     {
#       id:, name:, players: [... same hole shape as Best Ball + included_in_forty_score ],
#       player_count:, target_pick_count:, selected_count:,
#       total_selected_net:, total_selected_par:,
#       actual_vs_par:, competition_vs_par:
#     }
#   ],
#   leaderboard: [
#     { rank:, team_name:, player_count:, target_pick_count:,
#       actual_vs_par:, competition_vs_par:, total_selected_net:, total_selected_par: }
#   ]
# }
class FortyScoreScorecard
  include HandicapScoring

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

    total_selected_net = 0
    total_selected_par = 0
    selected_count = 0

    players_data.each do |p|
      p[:hole_scores].each do |row|
        next unless row[:included_in_forty_score]
        next if row[:net_score].nil?

        selected_count += 1
        total_selected_net += row[:net_score]
        total_selected_par += @round.hole_pars[row[:hole_number] - 1]
      end
    end

    player_count = team.game_team_players.size
    target = FortyScore.target_pick_count(player_count)

    # Standard golf vs par: Σ(net − par). Negative = under par (displays as e.g. −25).
    actual_vs_par =
      if selected_count == target
        total_selected_net - total_selected_par
      end

    competition_vs_par = FortyScore.competition_vs_par(
      actual_vs_par: actual_vs_par,
      player_count: player_count
    )

    {
      id: team.id,
      name: team.name,
      players: players_data,
      player_count: player_count,
      target_pick_count: target,
      selected_count: selected_count,
      total_selected_net: selected_count == target ? total_selected_net : nil,
      total_selected_par: selected_count == target ? total_selected_par : nil,
      actual_vs_par: actual_vs_par,
      competition_vs_par: competition_vs_par
    }
  end

  def build_player(gtp)
    hi = gtp.snapshot_handicap_index.to_f
    ch = course_handicap(hi)
    ph = playing_handicap(ch)
    scores_by_hole = gtp.hole_scores.index_by(&:hole_number)

    hole_scores = (1..18).map do |h|
      rec = scores_by_hole[h]
      strokes = strokes_on_hole(ph, h)
      gross = rec&.gross_score
      net = gross ? gross - strokes : nil
      {
        hole_number: h,
        gross_score: gross,
        net_score: net,
        strokes_received: strokes,
        included_in_forty_score: rec&.included_in_forty_score == true
      }
    end

    {
      name: gtp.user.name,
      course_handicap: ch,
      playing_handicap: ph,
      hole_scores: hole_scores
    }
  end

  def build_leaderboard(teams_data)
    rows = teams_data.map do |t|
      {
        team_name: t[:name],
        player_count: t[:player_count],
        target_pick_count: t[:target_pick_count],
        actual_vs_par: t[:actual_vs_par],
        competition_vs_par: t[:competition_vs_par],
        total_selected_net: t[:total_selected_net],
        total_selected_par: t[:total_selected_par]
      }
    end

    complete = rows.select { |r| r[:competition_vs_par].present? }
    incomplete = rows.reject { |r| r[:competition_vs_par].present? }
    sorted = complete.sort_by { |r| [ r[:competition_vs_par], r[:team_name] ] }

    ranked = []
    sorted.each_with_index do |row, idx|
      if idx.positive? && sorted[idx - 1][:competition_vs_par] == row[:competition_vs_par]
        ranked << row.merge(rank: ranked[idx - 1][:rank])
      else
        ranked << row.merge(rank: idx + 1)
      end
    end

    ranked + incomplete.map { |r| r.merge(rank: nil) }
  end
end
