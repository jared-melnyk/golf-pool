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

  def enter_forty_score_picks!(game, player_keys)
    round = game.round
    game.game_teams.includes(game_team_players: :user).each do |team|
      team.game_team_players.each do |gtp|
        player_key = @players_by_key.key(gtp.user)
        pick_offset = player_keys.index(player_key)
        (1..18).each do |hole|
          gross = gross_for(player_key, hole, :forty_score, round)
          picked = pick_hole?(hole, pick_offset)
          HoleScore.create!(
            game_team_player: gtp,
            hole_number: hole,
            gross_score: gross,
            included_in_forty_score: picked
          )
        end
      end
    end
  end

  def pick_hole?(hole, pick_offset)
    slots = (1..18).to_a.rotate(pick_offset * 3)
    slots.first(10).include?(hole)
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
    lines << "- Re-run with `bundle exec rake trip:simulate` to reset demo data."
    lines.join("\n")
  end

  def url_for(record)
    path = record.is_a?(Event) ? "/events/#{record.token}" : "/games/#{record.token}"
    "#{@host}#{path}"
  end
end
