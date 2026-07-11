# frozen_string_literal: true

class TripSimulation
  MANIFEST_PATH = Rails.root.join("tmp/trip_sim_manifest.md")

  def self.call(host: ENV.fetch("TRIP_SIM_HOST", "http://localhost:3000"))
    new(host: host).call
  end

  def initialize(host:)
    @host = host.chomp("/")
    @round_configs = {}
  end

  def call
    reset_previous_run!
    create_players_and_event!
    create_rounds_and_games!
    enter_scores!
    write_manifest!
    self
  end

  attr_reader :event, :commissioner, :players, :games_by_round, :winners

  private

  def reset_previous_run!
    trip_users = User.where("email LIKE ?", "trip-%@dryrun.test")
    trip_user_ids = trip_users.pluck(:id)

    Game.where(creator_id: trip_user_ids).find_each(&:destroy)
    [ TripConfig::EVENT_NAME, "Golf Trip Dry Run 2026" ].each do |name|
      Event.where(name: name).find_each(&:destroy)
    end
    trip_users.destroy_all
  end

  def create_players_and_event!
    @commissioner = User.create!(
      name: "Jared",
      email: "trip-commissioner@dryrun.test",
      password: TripConfig::PASSWORD,
      ghin_handicap_index: TripConfig.player(:jared)[:index]
    )
    @players = TripConfig::PLAYERS.map do |profile|
      User.create!(
        name: profile[:name],
        email: "trip-#{profile[:key]}@dryrun.test",
        password: TripConfig::PASSWORD,
        ghin_handicap_index: profile[:index]
      )
    end
    @players_by_key = TripConfig::PLAYERS.each_with_index.to_h { |profile, index| [ profile[:key], @players[index] ] }

    @event = Event.create!(name: TripConfig::EVENT_NAME, status: "active")
    EventMembership.create!(event: @event, user: @commissioner, role: "commissioner")
    @players.each { |player| EventMembership.create!(event: @event, user: player, role: "player") }
  end

  def create_rounds_and_games!
    @games_by_round = {}
    @winners = {}

    TripConfig::ROUNDS.each do |round_spec|
      round = create_round!(round_spec)
      @round_configs[round_spec[:key]] = round

      @games_by_round[round_spec[:key]] = case round_spec[:format]
      when "vegas"
        create_vegas_games!(round_spec, round)
      else
        create_foursome_games!(round_spec, round)
      end
    end
  end

  def create_foursome_games!(round_spec, round)
    groupings = TripConfig::FOURSOME_GROUPINGS.fetch(round_spec[:key])
    groupings.map.with_index do |player_keys, group_index|
      group_name = "Group #{('A'.ord + group_index).chr}"
      game = Game.create!(
        event: @event,
        round: round,
        game_type: round_spec[:format],
        status: "active",
        name: "#{group_name} · #{round.course_name}",
        creator: @commissioner
      )
      team = GameTeam.create!(game: game, name: group_name)
      player_keys.each { |key| GameTeamPlayer.create!(game_team: team, user: @players_by_key.fetch(key)) }
      game
    end
  end

  def create_vegas_games!(round_spec, round)
    TripConfig::VEGAS_MATCHES.map do |match|
      game = Game.create!(
        event: @event,
        round: round,
        game_type: "vegas",
        status: "active",
        name: "#{match[:name]} · #{round.course_name}",
        creator: @commissioner
      )
      match[:teams].each do |team_spec|
        team = GameTeam.create!(game: game, name: team_spec[:name])
        team_spec[:players].each { |key| GameTeamPlayer.create!(game_team: team, user: @players_by_key.fetch(key)) }
      end
      game
    end
  end

  def create_round!(round_spec)
    course_key = round_spec[:course_key]
    attrs = TripConfig.round_attrs(course_key)
    Round.create!(
      event: @event,
      name: "#{round_spec[:label]} · #{round_spec[:format_label]}",
      played_on: round_spec[:date],
      **attrs
    )
  end

  def enter_scores!
    enter_twelve_player_round!(:best_ball, complete_holes: 18)
    enter_twelve_player_round!(:cha_cha_cha, complete_holes: 18, gross_pattern: :cha_cha)
    enter_twelve_player_round!(:forty_score) do |game, keys|
      enter_forty_score_picks!(game, keys)
    end

    @games_by_round[:vegas].each_with_index do |game, _index|
      enter_team_scores!(game, complete_holes: 9, gross_pattern: :vegas)
      game.update!(status: "active")
      record_winner!(game, VegasScorecard, metric: :wash_margin, in_progress: true)
    end
  end

  def enter_twelve_player_round!(round_key, complete_holes: 18, gross_pattern: :default)
    scorecard_class = scorecard_class_for(round_key)
    metric = round_key == :forty_score ? :competition_vs_par : :total_net_strokes

    @games_by_round.fetch(round_key).each_with_index do |game, group_index|
      player_keys = TripConfig::FOURSOME_GROUPINGS.fetch(round_key)[group_index]
      if block_given?
        yield game, player_keys
      else
        enter_team_scores!(game, complete_holes: complete_holes, gross_pattern: gross_pattern)
      end
      complete_game!(game)
      record_winner!(game, scorecard_class, metric: metric)
    end
  end

  def scorecard_class_for(round_key)
    {
      best_ball: BestBallScorecard,
      cha_cha_cha: ChaChaChaScorecard,
      forty_score: FortyScoreScorecard
    }.fetch(round_key)
  end

  def enter_team_scores!(game, complete_holes:, gross_pattern: :default)
    round = game.round
    game.game_teams.includes(game_team_players: :user).each do |team|
      team.game_team_players.each do |gtp|
        player_key = @players_by_key.key(gtp.user)
        (1..complete_holes).each do |hole|
          gross = gross_for(player_key, hole, gross_pattern, round)
          HoleScore.create!(game_team_player: gtp, hole_number: hole, gross_score: gross)
        end
      end
    end
  end

  def enter_forty_score_picks!(game, _player_keys)
    round = game.round
    game.game_teams.includes(game_team_players: :user).each do |team|
      team.game_team_players.each do |gtp|
        player_key = @players_by_key.key(gtp.user)
        (1..18).each do |hole|
          gross = gross_for(player_key, hole, :forty_score, round)
          HoleScore.create!(
            game_team_player: gtp,
            hole_number: hole,
            gross_score: gross,
            included_in_forty_score: false
          )
        end
      end
    end

    apply_optimal_forty_picks!(game)
  end

  # 40 Score: captain picks how many scores to count per hole (0–4), 40 total.
  # On each hole, always take the lowest nets first (never count a worse score while
  # a better teammate's score on the same hole is left out).
  def apply_optimal_forty_picks!(game)
    game.reload
    scorecard = FortyScoreScorecard.new(game).call
    team_data = scorecard[:teams].first
    target = team_data[:target_pick_count]
    hole_pars = game.round.hole_pars

    # Per hole: nets sorted best-first (each player at most once per hole).
    hole_slots = {}
    (1..18).each do |hole_number|
      par = hole_pars[hole_number - 1]
      nets = []
      team_data[:players].each do |player|
        hs = player[:hole_scores].find { |s| s[:hole_number] == hole_number }
        next if hs[:net_score].nil?

        gtp = game.game_teams.flat_map(&:game_team_players).find { |g| g.user.name == player[:name] }
        nets << { gtp: gtp, hole_number: hole_number, vs_par: hs[:net_score] - par }
      end
      hole_slots[hole_number] = nets.sort_by { |n| [ n[:vs_par], n[:gtp].id ] }
    end

    # Greedily add the next-best available score on any hole until we reach the target.
    counts = Hash.new(0)
    target.times do
      best_hole = nil
      best_vs_par = nil
      hole_slots.each do |hole_number, nets|
        next if counts[hole_number] >= nets.size

        marginal = nets[counts[hole_number]][:vs_par]
        if best_hole.nil? || marginal < best_vs_par
          best_hole = hole_number
          best_vs_par = marginal
        end
      end
      counts[best_hole] += 1
    end

    counts.each do |hole_number, pick_count|
      hole_slots[hole_number].first(pick_count).each do |pick|
        HoleScore.find_by!(game_team_player: pick[:gtp], hole_number: pick[:hole_number])
                 .update!(included_in_forty_score: true)
      end
    end
  end

  def gross_for(player_key, hole, pattern, round)
    par = round.hole_pars[hole - 1]
    player_index = TripConfig.player_index(player_key)
    bias = player_index % 3

    case pattern
    when :cha_cha
      par + [ 0, 1, 2 ][(hole + player_index) % 3]
    when :vegas
      par + [ 0, 1, 1, 2 ][(hole + player_index) % 4]
    when :forty_score
      par + [ -1, 0, 1 ][(hole + bias) % 3]
    else
      par + [ 0, 1, 1, 2 ][(hole + bias) % 4]
    end
  end

  def complete_game!(game)
    game.update!(status: "completed")
  end

  def record_winner!(game, scorecard_class, metric: :total_net_strokes, in_progress: false)
    scorecard = scorecard_class.new(game.reload).call
    winner = case metric
    when :competition_vs_par
      scorecard[:leaderboard].min_by { |row| [ row[:competition_vs_par] || Float::INFINITY, row[:team_name] ] }
    when :wash_margin
      scorecard[:wash]
    else
      scorecard[:leaderboard].first
    end

    @winners[game.token] = {
      game_name: game.name,
      game_type: game.game_type,
      in_progress: in_progress,
      winner_name: winner_name_for(winner, metric),
      winning_summary: winning_summary_for(winner, metric)
    }
  end

  def winner_name_for(winner, metric)
    case metric
    when :wash_margin
      winner[:leader_name] || "All square"
    else
      winner[:team_name]
    end
  end

  def winning_summary_for(winner, metric)
    case metric
    when :competition_vs_par
      format_vs_par(winner[:competition_vs_par])
    when :wash_margin
      winner[:label]
    else
      winner[:total_net_strokes].to_s
    end
  end

  def format_vs_par(value)
    return "incomplete" if value.nil?

    value.zero? ? "E" : (value.positive? ? "+#{value}" : value.to_s)
  end

  def write_manifest!
    FileUtils.mkdir_p(MANIFEST_PATH.dirname)
    File.write(MANIFEST_PATH, manifest_body)
  end

  def manifest_body
    lines = []
    lines << "# #{TripConfig::EVENT_NAME} — Simulator Manifest"
    lines << ""
    lines << "Generated: #{Time.current.iso8601}"
    lines << ""
    lines << "Planning doc: `docs/trip/2026-07-michigan-golf-trip.md`"
    lines << ""
    lines << "## Before you click the URLs"
    lines << ""
    lines << "1. **Start the app** in another terminal: `bin/rails server` (or `bin/dev`)"
    if auto_login_links?
      lines << "2. **Click any link below** — each one signs you in as commissioner and opens that page (no separate login step)"
    else
      lines << "2. **Sign in** at #{@host}/login — use the commissioner credentials below"
      lines << "3. **Then** open the game/event links (they require a logged-in session)"
      lines << "4. For one-click login links, re-run with `TRIP_SIM_LOGIN=1` on the server and in this rake task"
    end
    lines << ""
    lines << "_These links point at `#{@host}`. They are not on production unless you re-run with `TRIP_SIM_HOST=https://long-shot-web.onrender.com bundle exec rake trip:simulate`._"
    lines << ""
    lines << "## Credentials"
    lines << ""
    lines << "| Role | Email | Password |"
    lines << "|------|-------|----------|"
    lines << "| Commissioner | `#{@commissioner.email}` | `#{TripConfig::PASSWORD}` |"
    lines << "| Players | `trip-{name-key}@dryrun.test` | `#{TripConfig::PASSWORD}` |"
    lines << ""
    lines << "## Event"
    lines << ""
    lines << "- URL: #{url_for(@event)}"
    lines << "- Vegas sit-outs: #{TripConfig.vegas_sit_out_names.join(', ')}"
    lines << ""
    lines << "## Rounds and games"
    lines << ""

    TripConfig::ROUNDS.each do |round_spec|
      games = @games_by_round.fetch(round_spec[:key])
      status_label = round_spec[:key] == :vegas ? "front 9 in progress" : "completed"
      lines << "### #{round_spec[:label]} · #{round_spec[:format_label]} (#{status_label})"
      lines << ""
      lines << "- **When:** #{round_spec[:date].strftime('%A, %B %-d, %Y')} · #{round_spec[:tee_time]}"
      lines << "- **Course:** #{TripConfig.course(round_spec[:course_key])[:club_name]} — #{TripConfig.course(round_spec[:course_key])[:course_name]}"
      lines << ""

      games.each do |game|
        winner = @winners.fetch(game.token)
        status = winner[:in_progress] ? "in progress" : "completed"
        lines << "- **#{game.name}** (#{status})"
        lines << "  - URL: #{url_for(game)}"
        lines << "  - Expected leader: **#{winner[:winner_name]}** (#{winner[:winning_summary]})"
      end
      lines << ""
    end

    lines << "## Notes"
    lines << ""
    lines << "- Leaderboards are per game, not event-wide."
    lines << "- Re-run with `bundle exec rake trip:simulate` to reset demo data (old URLs stop working after a re-run)."
    lines << "- If a link 404s or redirects oddly, re-run the simulator and use the fresh manifest."
    lines.join("\n")
  end

  def url_for(record)
    path = record.is_a?(Event) ? "/events/#{record.token}" : "/games/#{record.token}"
    return "#{@host}#{path}" unless auto_login_links?

    "#{@host}/dev/trip_sim_login?return_to=#{CGI.escape(path)}"
  end

  def auto_login_links?
    host = @host.to_s
    host.include?("localhost") ||
      host.include?("127.0.0.1") ||
      ActiveModel::Type::Boolean.new.cast(ENV["TRIP_SIM_LOGIN"])
  end
end
