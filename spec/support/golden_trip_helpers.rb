# frozen_string_literal: true

module GoldenTripHelpers
  DEFAULT_ROUND = {
    "course_rating" => 72.0,
    "slope_rating" => 113,
    "par_total" => 72,
    "hole_pars" => Array.new(18, 4),
    "hole_handicaps" => [ 1, 3, 5, 7, 9, 11, 13, 15, 17, 2, 4, 6, 8, 10, 12, 14, 16, 18 ]
  }.freeze

  SCORECARD_SERVICES = {
    "best_ball" => BestBallScorecard,
    "cha_cha_cha" => ChaChaChaScorecard,
    "forty_score" => FortyScoreScorecard,
    "vegas" => VegasScorecard
  }.freeze

  def load_golden_fixture(path)
    YAML.safe_load_file(path, permitted_classes: [ Date ])
  end

  def build_golden_game!(fixture)
    round_attrs = DEFAULT_ROUND.merge(fixture.fetch("round", {}))
    event = Event.create!(name: "Golden #{fixture['id']}", status: "active")
    round = Round.create!(
      event: event,
      name: "Round 1",
      played_on: Date.today,
      golf_course_api_course_id: 1,
      course_name: "Golden Course",
      tee_name: "White",
      tee_gender: "male",
      **round_attrs.symbolize_keys
    )
    creator = User.create!(
      name: "Host",
      email: "host-#{fixture['id']}@golden.test",
      password: "pw"
    )
    game = Game.create!(
      event: event,
      round: round,
      game_type: fixture.fetch("format"),
      status: "active",
      name: fixture.fetch("id"),
      creator: creator
    )

    player_gtps = {}
    fixture.fetch("teams").each do |team_spec|
      team = GameTeam.create!(game: game, name: team_spec.fetch("name"))
      team_spec.fetch("players").each do |player_spec|
        user = User.create!(
          name: player_spec.fetch("name"),
          email: "#{player_spec.fetch('name').parameterize}-#{fixture['id']}@golden.test",
          password: "pw",
          ghin_handicap_index: player_spec.fetch("handicap_index", 0.0)
        )
        gtp = GameTeamPlayer.create!(game_team: team, user: user)
        player_gtps[[ team_spec["name"], player_spec["name"] ]] = gtp
      end
    end

    fixture.fetch("teams").each do |team_spec|
      team_spec.fetch("players").each do |player_spec|
        gtp = player_gtps[[ team_spec["name"], player_spec["name"] ]]
        apply_player_scores!(gtp, player_spec)
      end
    end

    [ game.reload, player_gtps ]
  end

  def scorecard_for(fixture, game)
    SCORECARD_SERVICES.fetch(fixture.fetch("format")).new(game).call
  end

  def assert_golden_expectations!(fixture, scorecard)
    expected = fixture.fetch("expected")

    if expected["teams"]
      expected["teams"].each do |team_name, team_expected|
        team = scorecard[:teams].find { |t| t[:name] == team_name }
        raise "Team #{team_name} not found" unless team

        team_expected.each do |key, value|
          case key
          when "players"
            value.each do |player_name, player_expected|
              player = team[:players].find { |p| p[:name] == player_name }
              raise "Player #{player_name} not found on #{team_name}" unless player

              player_expected.each do |attr, expected_value|
                expect(player[attr.to_sym]).to eq(expected_value), "#{fixture['id']}: #{team_name}/#{player_name}/#{attr}"
              end
            end
          when "hole_scores"
            value.each do |hole_number, hole_expected|
              hole = team[:hole_scores].find { |h| h[:hole_number] == hole_number.to_i }
              hole_expected.each do |attr, expected_value|
                expect(hole[attr.to_sym]).to eq(expected_value), "#{fixture['id']}: #{team_name} hole #{hole_number}/#{attr}"
              end
            end
          else
            expect(team[key.to_sym]).to eq(value), "#{fixture['id']}: #{team_name}/#{key}"
          end
        end
      end
    end

    if expected["holes"]
      expected["holes"].each do |hole_number, hole_expected|
        hole = scorecard[:holes].find { |h| h[:hole_number] == hole_number.to_i }
        hole_expected.each do |attr, expected_value|
          actual = hole[attr.to_sym]
          if attr == "team_numbers" && expected_value.is_a?(Hash)
            expected_value.each do |team_name, number|
              team_id = scorecard[:teams].find { |t| t[:name] == team_name }&.dig(:id)
              expect(actual[team_id]).to eq(number), "#{fixture['id']}: hole #{hole_number} team_numbers[#{team_name}]"
            end
          else
            expect(actual).to eq(expected_value), "#{fixture['id']}: hole #{hole_number}/#{attr}"
          end
        end
      end
    end

    if expected["wash"]
      expected["wash"].each do |key, value|
        expect(scorecard[:wash][key.to_sym]).to eq(value), "#{fixture['id']}: wash/#{key}"
      end
    end

    if expected["leaderboard"]
      expected["leaderboard"].each do |row_expected|
        row = scorecard[:leaderboard].find { |r| r[:team_name] == row_expected["team_name"] }
        row_expected.each do |key, value|
          expect(row[key.to_sym]).to eq(value), "#{fixture['id']}: leaderboard #{row_expected['team_name']}/#{key}"
        end
      end
    end
  end

  private

  def apply_player_scores!(gtp, player_spec)
    gross_scores = normalize_scores(player_spec["gross_scores"])
    forty_picks = Array(player_spec["forty_picks"]).map(&:to_i)

    (1..18).each do |hole_number|
      gross = gross_scores[hole_number - 1]
      next if gross.nil?

      HoleScore.create!(
        game_team_player: gtp,
        hole_number: hole_number,
        gross_score: gross,
        included_in_forty_score: forty_picks.include?(hole_number)
      )
    end
  end

  def normalize_scores(raw)
    return Array.new(18) unless raw

    case raw
    when Array
      raw
    when Hash
      scores = Array.new(18)
      raw.each { |hole, score| scores[hole.to_i - 1] = score }
      scores
    else
      raise ArgumentError, "gross_scores must be an array or hole hash"
    end
  end
end

RSpec.configure do |config|
  config.include GoldenTripHelpers
end
