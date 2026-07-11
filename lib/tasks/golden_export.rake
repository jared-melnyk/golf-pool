# frozen_string_literal: true

namespace :golden do
  desc "Export golden trip fixtures to manual validation markdown packets"
  task export_validation: :environment do
    require Rails.root.join("lib/golden_trip_helpers")
    include GoldenTripHelpers

    Event.where("name LIKE ?", "Golden %").find_each(&:destroy!)
    User.where("email LIKE ?", "%@golden.test").find_each(&:destroy!)

    out_dir = Rails.root.join("docs/validation/packets")
    FileUtils.mkdir_p(out_dir)

    # Primary: realistic scenarios mirroring the actual trip rounds/courses/groups.
    trip_scenarios = %w[
      trip_vegas_arcadia
      trip_bb_wolf_river
      trip_ccc_champion_hill
      trip_fs_pinecroft
    ]

    # Secondary: focused edge cases with simple data that isolate a single rule.
    edge_scenarios = %w[
      bb_ph_over_18
      fs_threesome_competition
      vegas_handicap
      vegas_tie
    ]

    counter = 0
    (trip_scenarios + edge_scenarios).each do |id|
      counter += 1
      group = trip_scenarios.include?(id) ? "trip" : "edge"
      fixture = load_golden_fixture(Rails.root.join("spec/fixtures/golden_trips/#{id}.yml"))
      game, = build_golden_game!(fixture)
      scorecard = scorecard_for(fixture, game)

      content = GoldenValidationExporter.render_packet(fixture, game, scorecard, group: group)
      filename = format("%02d-%s-%s.md", counter, group, id)
      File.write(out_dir.join(filename), content)
      puts "Wrote #{filename}"
    end

    puts "\nDone. Packets in docs/validation/packets/"
  end
end

# rubocop:disable Metrics/ModuleLength
module GoldenValidationExporter
  module_function

  FORMAT_LABELS = {
    "best_ball" => "Best Ball",
    "cha_cha_cha" => "Cha-Cha-Cha (1-2-3)",
    "forty_score" => "40 Score",
    "vegas" => "Vegas (2v2 wash)"
  }.freeze

  def render_packet(fixture, game, scorecard, group:)
    round = game.round
    format = fixture["format"]
    lines = []
    lines << "# Manual validation: #{fixture['id']}"
    lines << ""
    lines << "**Format:** #{FORMAT_LABELS.fetch(format, format)}  "
    lines << "**Scenario:** #{fixture['description']}  "
    lines << "**Type:** #{group == 'trip' ? 'Realistic trip scenario' : 'Edge-case rule check'}"
    lines << ""
    lines << "> Work through the **worksheet** first, then compare your answers to the **expected results** at the bottom."
    lines << ""
    lines << course_section(round)
    lines << handicap_terms_section(format, round, fixture, scorecard)
    lines << players_section(fixture, scorecard)
    lines << gross_section(round, scorecard)
    lines << worksheet_section(format)
    lines << expected_results_section(format, scorecard, round)
    lines << ""
    lines.join("\n")
  end

  def course_section(round)
    lines = [ "## Course & tee snapshot", "" ]
    lines << "| Field | Value |"
    lines << "|-------|-------|"
    lines << "| Rating | #{round.course_rating} |"
    lines << "| Slope | #{round.slope_rating} |"
    lines << "| Par (total) | #{round.par_total} |"
    lines << ""
    lines << "| Hole | #{(1..18).to_a.join(' | ')} |"
    lines << "|------|#{([ '---' ] * 18).join('|')}|"
    lines << "| Par | #{round.hole_pars.join(' | ')} |"
    lines << "| Stroke index | #{round.hole_handicaps.join(' | ')} |"
    lines << ""
    lines.join("\n")
  end

  def handicap_terms_section(format, round, fixture, scorecard)
    allowance = allowance_percent(format)
    rating = round.course_rating.to_f
    slope = round.slope_rating.to_f
    par = round.par_total.to_f
    slope_factor = (slope / 113.0).round(3)

    example_player = scorecard[:teams].first[:players].first
    example_team = scorecard[:teams].first[:name]
    example_hi = fixture_player_hi(fixture, example_team, example_player[:name]).to_f
    example_ch = example_player[:course_handicap]
    example_ph = example_player[:playing_handicap]
    ch_step = (example_hi * (slope / 113.0) + (rating - par)).round(1)
    ph_step = (example_ch * allowance / 100.0).round(1)

    lines = [ "## Handicap terms (HI, CH, PH)", "" ]
    lines << "| Abbrev | Full name | What it means |"
    lines << "|--------|-----------|---------------|"
    lines << "| **HI** | Handicap Index | Player’s GHIN number — overall skill level (lower = better). Listed in the trip roster. |"
    lines << "| **CH** | Course Handicap | Strokes for **this course and tee** — adjusts HI for slope, rating, and par. |"
    lines << "| **PH** | Playing Handicap | CH adjusted for **this game format** (allowance %), capped at **36**. Used to allocate strokes hole by hole. |"
    lines << ""
    lines << "### Formulas (this packet)"
    lines << ""
    lines << "**Course Handicap**"
    lines << ""
    lines << "```"
    lines << "CH = round( HI × (slope ÷ 113) + (rating − par) )"
    lines << "```"
    lines << ""
    lines << "This course: rating **#{rating}**, slope **#{slope.to_i}**, par **#{par.to_i}**"
    lines << ""
    lines << "```"
    lines << "CH = round( HI × #{slope_factor} + (#{rating} − #{par.to_i}) )"
    lines << "```"
    lines << ""
    lines << "**Playing Handicap** (#{FORMAT_LABELS.fetch(format)} uses **#{allowance}%** of CH, max **36**)"
    lines << ""
    lines << "```"
    lines << "PH = min( round( CH × #{allowance}% ), 36 )"
    lines << "```"
    lines << ""
    lines << "**Worked example — #{example_player[:name]} (HI #{example_hi}):**"
    lines << "1. CH = round(#{example_hi} × #{slope_factor} + (#{rating} − #{par.to_i})) = round(#{ch_step}) = **#{example_ch}**"
    uncapped_ph = (example_ch * allowance / 100.0).round
    if uncapped_ph > example_ph
      lines << "2. PH = min(round(#{example_ch} × #{allowance}%), 36) = min(#{uncapped_ph}, 36) = **#{example_ph}**"
    else
      lines << "2. PH = min(round(#{example_ch} × #{allowance}%), 36) = round(#{ph_step}) = **#{example_ph}**"
    end
    lines << ""
    lines << "**Net score on a hole** = gross score − strokes received on that hole."
    lines << ""
    lines << "**Strokes per hole:** PH strokes are spread across 18 holes using the **stroke index (SI)** row in the course table (SI 1 = hardest hole)."
    lines << "- If PH ≤ 18: player gets **1 stroke** on the PH hardest holes (SI 1 through SI PH)."
    lines << "- If PH > 18: every hole gets **1 stroke**, plus an **extra stroke** on the (PH − 18) hardest holes (max PH 36 ⇒ max 2 per hole)."
    lines << ""
    lines << "_The **Total strokes** column in the table below should equal each player’s PH._"
    lines << ""
    lines.join("\n")
  end

  def allowance_percent(format)
    case format
    when "best_ball", "cha_cha_cha" then 85
    when "forty_score", "vegas" then 100
    else 100
    end
  end

  def players_section(fixture, scorecard)
    lines = [ "## Players and handicaps", "" ]
    lines << "See **Handicap terms** above for how HI → CH → PH is calculated."
    lines << ""
    lines << "| Team | Player | HI | CH | PH | Total strokes |"
    lines << "|------|--------|----|----|----|---------------|"
    scorecard[:teams].each do |team|
      team[:players].each do |player|
        hi = fixture_player_hi(fixture, team[:name], player[:name])
        total_strokes = player[:hole_scores].sum { |h| h[:strokes_received].to_i }
        lines << "| #{team[:name]} | #{player[:name]} | #{hi} | #{player[:course_handicap]} | #{player[:playing_handicap]} | #{total_strokes} |"
      end
    end
    lines << ""
    lines.join("\n")
  end

  def gross_section(round, scorecard)
    players = flat_players(scorecard)
    lines = [ "## Gross scores entered (the scorecard)", "" ]
    header = [ "Hole", "Par", "SI" ] + players.map { |p| p[:name] }
    lines << "| #{header.join(' | ')} |"
    lines << "|#{([ '---' ] * header.size).join('|')}|"
    (1..18).each do |h|
      row = [ h, round.hole_pars[h - 1], round.hole_handicaps[h - 1] ]
      players.each do |p|
        row << (p[:hole_scores].find { |s| s[:hole_number] == h }&.dig(:gross_score) || "")
      end
      lines << "| #{row.join(' | ')} |"
    end
    lines << ""
    lines.join("\n")
  end

  def worksheet_section(format)
    lines = [ "## Your manual calculation worksheet", "" ]
    lines.concat(worksheet_instructions(format))
    lines << ""
    lines << "| Hole | Your result | Match? |"
    lines << "|------|-------------|--------|"
    (1..18).each { |h| lines << "| #{h} | | ☐ |" }
    lines << "| **Total / summary** | | ☐ |"
    lines << ""
    lines.join("\n")
  end

  def worksheet_instructions(format)
    case format
    when "best_ball"
      [
        "For each hole: net = gross − strokes received; team result = **lowest net** among the four players.",
        "Total = sum of the 18 hole best-ball nets."
      ]
    when "cha_cha_cha"
      [
        "Count pattern repeats every 3 holes: holes 1,4,7,… count **1** best net; 2,5,8,… count **2**; 3,6,9,… count **3**.",
        "Hole result = sum of the counted nets. Total = sum of all 18 hole results."
      ]
    when "forty_score"
      [
        "For each **picked** hole (✓ in the expected-results table), compute net − par. Sum across all 40 picks = team actual vs par.",
        "Threesomes only: competition vs par = round(actual × 4/3). Foursomes: competition = actual."
      ]
    when "vegas"
      [
        "Per hole: net (cap any net > 9 to 9) → team number (lower net = tens, higher = ones).",
        "Birdie flip: if either player on a team nets birdie-or-better (net ≤ par−1), flip the **opponent's** digits.",
        "Points = opponent number − your number (to the lower team). Wash = running sum from Team A's view."
      ]
    else
      []
    end
  end

  def expected_results_section(format, scorecard, round)
    lines = [ "---", "", "## Expected results (from the app — compare your worksheet here)", "" ]
    case format
    when "best_ball"
      lines << best_ball_expected_results(scorecard, round)
    when "cha_cha_cha"
      lines << cha_cha_cha_expected_results(scorecard, round)
    when "forty_score"
      lines << forty_score_expected_results(scorecard, round)
    when "vegas"
      lines << vegas_expected_results(scorecard, round)
    end
    lines.join("\n")
  end

  def best_ball_expected_results(scorecard, round)
    team = scorecard[:teams].first
    players = team[:players]
    lines = [ "### #{team[:name]} — hole by hole", "" ]
    header = [ "Hole", "Par" ] + players.map { |p| "#{p[:name]} net" } + [ "**Best net**" ]
    lines << "| #{header.join(' | ')} |"
    lines << "|#{([ '---' ] * header.size).join('|')}|"
    team[:hole_scores].each do |hs|
      row = [ hs[:hole_number], round.hole_pars[hs[:hole_number] - 1] ]
      players.each { |p| row << net_for(p, hs[:hole_number]) }
      row << "**#{hs[:best_ball_net]}**"
      lines << "| #{row.join(' | ')} |"
    end
    lines << ""
    lines << "**Team total net strokes: #{team[:total_net_strokes]}**"
    lines << ""
    lines.join("\n")
  end

  def cha_cha_cha_expected_results(scorecard, round)
    team = scorecard[:teams].first
    players = team[:players]
    lines = [ "### #{team[:name]} — hole by hole", "" ]
    header = [ "Hole", "Par", "Count" ] + players.map { |p| "#{p[:name]} net" } + [ "**Hole total**" ]
    lines << "| #{header.join(' | ')} |"
    lines << "|#{([ '---' ] * header.size).join('|')}|"
    team[:hole_scores].each do |hs|
      row = [ hs[:hole_number], round.hole_pars[hs[:hole_number] - 1], hs[:scores_to_count] ]
      players.each { |p| row << net_for(p, hs[:hole_number]) }
      row << "**#{hs[:team_net_strokes]}**"
      lines << "| #{row.join(' | ')} |"
    end
    lines << ""
    lines << "**Team total net strokes: #{team[:total_net_strokes]}**"
    lines << ""
    lines.join("\n")
  end

  def forty_score_expected_results(scorecard, round)
    team = scorecard[:teams].first
    players = team[:players]
    lines = [ "### #{team[:name]} — picks and net vs par", "" ]
    lines << "Cells show **net** (✓ = counted in the 40). Par is per hole below."
    lines << ""
    header = [ "Hole", "Par" ] + players.map { |p| p[:name] }
    lines << "| #{header.join(' | ')} |"
    lines << "|#{([ '---' ] * header.size).join('|')}|"
    (1..18).each do |h|
      row = [ h, round.hole_pars[h - 1] ]
      players.each do |p|
        cell = p[:hole_scores].find { |s| s[:hole_number] == h }
        net = cell&.dig(:net_score)
        picked = cell&.dig(:included_in_forty_score)
        row << (net.nil? ? "" : "#{net}#{picked ? ' ✓' : ''}")
      end
      lines << "| #{row.join(' | ')} |"
    end
    lines << ""
    lines << "- **Picks counted:** #{team[:selected_count]} / #{team[:target_pick_count]}"
    lines << "- **Actual vs par:** #{format_vs_par(team[:actual_vs_par])}"
    lines << "- **Competition vs par:** #{format_vs_par(team[:competition_vs_par])}"
    lines << ""
    lines.join("\n")
  end

  def vegas_expected_results(scorecard, _round)
    teams = scorecard[:teams]
    a, b = teams
    lines = [ "### Hole by hole", "" ]
    header = [
      "Hole", "Par",
      "#{a[:name]} nets", "#{a[:name]} #",
      "#{b[:name]} nets", "#{b[:name]} #",
      "Flip", "Points", "Wash"
    ]
    lines << "| #{header.join(' | ')} |"
    lines << "|#{([ '---' ] * header.size).join('|')}|"
    scorecard[:holes].each do |hole|
      next unless hole[:complete]

      flip = hole[:flipped_team_ids].map { |tid| teams.find { |t| t[:id] == tid }[:name] }.join(", ")
      row = [
        hole[:hole_number], hole[:par],
        capped_nets(a, hole[:hole_number]), hole[:team_numbers][a[:id]],
        capped_nets(b, hole[:hole_number]), hole[:team_numbers][b[:id]],
        flip.presence || "—",
        hole[:hole_points], hole[:running_wash]
      ]
      lines << "| #{row.join(' | ')} |"
    end
    lines << ""
    w = scorecard[:wash]
    lines << "**Result: #{w[:label]}** (margin #{w[:margin]}, from #{a[:name]}'s perspective)"
    lines << ""
    lines << "_Points/wash are shown from #{a[:name]}'s view: negative = #{b[:name]} won the hole._"
    lines << ""
    lines.join("\n")
  end

  def flat_players(scorecard)
    scorecard[:teams].flat_map { |t| t[:players] }
  end

  def net_for(player, hole_number)
    player[:hole_scores].find { |s| s[:hole_number] == hole_number }&.dig(:net_score) || ""
  end

  def capped_nets(team, hole_number)
    team[:players].map do |p|
      cell = p[:hole_scores].find { |s| s[:hole_number] == hole_number }
      cell&.dig(:capped_net) || cell&.dig(:net_score)
    end.join("/")
  end

  def format_vs_par(value)
    return "—" if value.nil?

    value.positive? ? "+#{value}" : value.to_s
  end

  def fixture_player_hi(fixture, team_name, player_name)
    team = fixture["teams"].find { |t| t["name"] == team_name }
    player = team["players"].find { |p| p["name"] == player_name }
    player.fetch("handicap_index", 0.0)
  end
end
# rubocop:enable Metrics/ModuleLength
