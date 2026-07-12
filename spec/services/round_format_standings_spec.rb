# frozen_string_literal: true

require "rails_helper"

RSpec.describe RoundFormatStandings do
  let(:event) { Event.create!(name: "Trip", status: "active") }
  let(:round) do
    Round.create!(
      event: event, name: "Wolf River", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "Wolf River", tee_name: "W",
      tee_gender: "male", course_rating: 72.0, slope_rating: 113, par_total: 72,
      hole_pars: Array.new(18, 4),
      hole_handicaps: (1..18).to_a
    )
  end

  def add_field_game!(name:, gross:)
    game = create_test_game!(event: event, round: round, game_type: "best_ball", name: name)
    user = User.create!(name: name, email: "#{name.parameterize}@test.com", password: "pw", ghin_handicap_index: 0.0)
    team = GameTeam.create!(game: game, name: name)
    gtp = GameTeamPlayer.create!(game_team: team, user: user)
    (1..18).each { |h| HoleScore.create!(game_team_player: gtp, hole_number: h, gross_score: gross) }
    game
  end

  describe "#call" do
    it "ranks field best-ball teams across sibling games (lower net wins)" do
      add_field_game!(name: "Group A", gross: 5)
      add_field_game!(name: "Group B", gross: 3)
      add_field_game!(name: "Group C", gross: 4)

      result = described_class.new(round: round, game_type: "best_ball").call

      expect(result[:field].map { |row| row[:team_name] }).to eq([ "Group B", "Group C", "Group A" ])
      expect(result[:field].map { |row| row[:rank] }).to eq([ 1, 2, 3 ])
      expect(result[:field].first[:metric_key]).to eq(:total_net_strokes)
      expect(result[:field].first[:scope]).to eq(:field)
      expect(result[:matches]).to eq([])
    end

    it "excludes match (multi-team) best_ball games from the field board" do
      add_field_game!(name: "Group A", gross: 4)

      match = create_test_game!(event: event, round: round, game_type: "best_ball", name: "2v2")
      u1 = User.create!(name: "M1", email: "m1@test.com", password: "pw", ghin_handicap_index: 0)
      u2 = User.create!(name: "M2", email: "m2@test.com", password: "pw", ghin_handicap_index: 0)
      t1 = GameTeam.create!(game: match, name: "Side 1")
      t2 = GameTeam.create!(game: match, name: "Side 2")
      g1 = GameTeamPlayer.create!(game_team: t1, user: u1)
      g2 = GameTeamPlayer.create!(game_team: t2, user: u2)
      (1..18).each do |h|
        HoleScore.create!(game_team_player: g1, hole_number: h, gross_score: 4)
        HoleScore.create!(game_team_player: g2, hole_number: h, gross_score: 5)
      end

      result = described_class.new(round: round, game_type: "best_ball").call

      expect(result[:field].map { |row| row[:team_name] }).to eq([ "Group A" ])
      expect(result[:matches].size).to eq(1)
      expect(result[:matches].first[:game_id]).to eq(match.id)
      expect(result[:matches].first[:game_name]).to eq("2v2")
    end

    it "lists incomplete field teams without a rank after complete ones" do
      add_field_game!(name: "Done", gross: 4)
      incomplete = create_test_game!(event: event, round: round, game_type: "best_ball", name: "WIP")
      user = User.create!(name: "WIP", email: "wip@test.com", password: "pw", ghin_handicap_index: 0)
      team = GameTeam.create!(game: incomplete, name: "WIP")
      gtp = GameTeamPlayer.create!(game_team: team, user: user)
      HoleScore.create!(game_team_player: gtp, hole_number: 1, gross_score: 4)

      result = described_class.new(round: round, game_type: "best_ball").call

      expect(result[:field].first[:team_name]).to eq("Done")
      expect(result[:field].first[:rank]).to eq(1)
      expect(result[:field].last[:team_name]).to eq("WIP")
      expect(result[:field].last[:rank]).to be_nil
    end
  end
end
