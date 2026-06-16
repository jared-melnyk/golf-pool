# frozen_string_literal: true

# Computes a Vegas (2v2 wash) scorecard for a given Game.
# Each team combines two capped net scores into a two-digit number; lower wins the hole.
# Returns a structured hash per docs/plans/2026-06-10-vegas-design.md §4.3.
class VegasScorecard
  def initialize(game)
    @game = game
    @round = game.round
    @allowance = game.playing_handicap_allowance_percent
  end

  def call
    teams = @game.game_teams.order(:id).includes(game_team_players: [ :user, :hole_scores ]).to_a
    reference_team = teams.first
    teams_data = teams.map { |team| build_team(team) }

    running_wash = 0
    holes = (1..18).map do |h|
      build_hole(h, teams, teams_data, reference_team.id, running_wash).tap do |hole|
        running_wash = hole[:running_wash] if hole[:running_wash].present?
      end
    end

    {
      reference_team_id: reference_team&.id,
      teams: teams_data,
      holes: holes,
      wash: build_wash(teams, reference_team, holes, running_wash)
    }
  end

  private

  def build_team(team)
    players_data = team.game_team_players.map { |gtp| build_player(gtp) }

    { id: team.id, name: team.name, players: players_data }
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
      capped = Vegas.cap_net(net)
      { hole_number: h, gross_score: gross, net_score: net, strokes_received: strokes, capped_net: capped }
    end

    {
      name: gtp.user.name,
      course_handicap: ch,
      playing_handicap: ph,
      hole_scores: hole_scores
    }
  end

  def build_hole(hole_number, teams, teams_data, reference_team_id, running_wash_before)
    par = @round.hole_pars[hole_number - 1]
    nets_by_team = teams_data.to_h do |team|
      player_nets = team[:players].map do |p|
        p[:hole_scores].find { |s| s[:hole_number] == hole_number }&.dig(:net_score)
      end
      [ team[:id], player_nets ]
    end

    complete = nets_by_team.values.all? { |nets| nets.all?(&:present?) }

    unless complete
      return {
        hole_number: hole_number,
        par: par,
        team_numbers: {},
        flipped_team_ids: [],
        birdie_team_ids: [],
        hole_points: nil,
        running_wash: nil,
        complete: false
      }
    end

    capped_by_team = nets_by_team.transform_values do |nets|
      nets.map { |n| Vegas.cap_net(n) }
    end

    birdie_team_ids = teams.filter_map do |team|
      nets = nets_by_team[team.id]
      team.id if nets.any? { |n| Vegas.birdie_or_better?(n, par) }
    end

    flipped_team_ids = teams.filter_map do |team|
      opponent = teams.find { |t| t.id != team.id }
      opponent.id if birdie_team_ids.include?(team.id)
    end

    team_numbers = teams.to_h do |team|
      capped = capped_by_team[team.id]
      flipped = flipped_team_ids.include?(team.id)
      [ team.id, Vegas.team_number(capped[0], capped[1], flipped: flipped) ]
    end

    ref_number = team_numbers[reference_team_id]
    opp_id = teams.find { |t| t.id != reference_team_id }.id
    opp_number = team_numbers[opp_id]
    hole_points = Vegas.hole_points(ref_number, opp_number)
    running_wash = running_wash_before + hole_points

    {
      hole_number: hole_number,
      par: par,
      team_numbers: team_numbers,
      flipped_team_ids: flipped_team_ids,
      birdie_team_ids: birdie_team_ids,
      hole_points: hole_points,
      running_wash: running_wash,
      complete: true
    }
  end

  def build_wash(teams, reference_team, holes, running_wash)
    complete_holes = holes.select { |h| h[:complete] }

    if complete_holes.empty? || reference_team.nil?
      return { margin: nil, leader_team_id: nil, leader_name: nil, label: "All square" }
    end

    margin = running_wash
    opponent = teams.find { |t| t.id != reference_team.id }

    if margin.zero?
      { margin: 0, leader_team_id: nil, leader_name: nil, label: "All square" }
    elsif margin.positive?
      {
        margin: margin,
        leader_team_id: reference_team.id,
        leader_name: reference_team.name,
        label: "#{reference_team.name} leads by #{margin}"
      }
    else
      {
        margin: margin,
        leader_team_id: opponent.id,
        leader_name: opponent.name,
        label: "#{opponent.name} leads by #{margin.abs}"
      }
    end
  end

  def course_handicap(hi)
    slope = @round.slope_rating.to_f
    rating = @round.course_rating.to_f
    par = @round.par_total.to_f
    (hi * (slope / 113.0) + (rating - par)).round
  end

  def playing_handicap(ch)
    (ch * @allowance / 100.0).round
  end

  def strokes_on_hole(playing_handicap, hole_number)
    return 0 if playing_handicap <= 0

    si = @round.hole_handicaps[hole_number - 1]
    base = playing_handicap / 18
    return base if si.nil?

    remainder = playing_handicap % 18
    base + (si <= remainder ? 1 : 0)
  end
end
