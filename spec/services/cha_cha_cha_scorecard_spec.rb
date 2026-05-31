# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChaChaChaScorecard do
  let(:event) { Event.create!(name: "E", status: "active") }
  let(:round) do
    Round.create!(
      event: event, name: "R", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "C", tee_name: "W",
      tee_gender: "male", course_rating: 72.0, slope_rating: 113, par_total: 72,
      hole_pars:      [ 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 ],
      hole_handicaps: [ 1, 3, 5, 7, 9, 11, 13, 15, 17, 2, 4, 6, 8, 10, 12, 14, 16, 18 ]
    )
  end
  let(:game) { create_test_game!(event: event, round: round, game_type: "cha_cha_cha") }

  let(:alice) { User.create!(name: "Alice", email: "alice-ccc@test.com", password: "pw", ghin_handicap_index: 18.0) }
  let(:bob)   { User.create!(name: "Bob",   email: "bob-ccc@test.com",   password: "pw", ghin_handicap_index: 0.0) }
  let(:carol) { User.create!(name: "Carol", email: "carol-ccc@test.com", password: "pw", ghin_handicap_index: 10.0) }
  let(:dave)  { User.create!(name: "Dave",  email: "dave-ccc@test.com",  password: "pw", ghin_handicap_index: 5.0) }

  let(:team_a) { GameTeam.create!(game: game, name: "Team A") }
  let(:gtp_alice) { GameTeamPlayer.create!(game_team: team_a, user: alice) }
  let(:gtp_bob)   { GameTeamPlayer.create!(game_team: team_a, user: bob) }
  let(:gtp_carol) { GameTeamPlayer.create!(game_team: team_a, user: carol) }
  let(:gtp_dave)  { GameTeamPlayer.create!(game_team: team_a, user: dave) }

  before do
    (1..18).each do |h|
      HoleScore.create!(game_team_player: gtp_alice, hole_number: h, gross_score: 5)
      HoleScore.create!(game_team_player: gtp_bob,   hole_number: h, gross_score: 4)
      HoleScore.create!(game_team_player: gtp_carol, hole_number: h, gross_score: 6)
      HoleScore.create!(game_team_player: gtp_dave,  hole_number: h, gross_score: 5)
    end
  end

  subject(:scorecard) { ChaChaChaScorecard.new(game).call }

  it "uses 85% playing handicap allowance" do
    expect(game.playing_handicap_allowance_percent).to eq(85)
  end

  it "records scores_to_count per hole in the 1-2-3 pattern" do
    team = scorecard[:teams].first
    expect(team[:hole_scores].find { |s| s[:hole_number] == 1 }[:scores_to_count]).to eq(1)
    expect(team[:hole_scores].find { |s| s[:hole_number] == 2 }[:scores_to_count]).to eq(2)
    expect(team[:hole_scores].find { |s| s[:hole_number] == 3 }[:scores_to_count]).to eq(3)
    expect(team[:hole_scores].find { |s| s[:hole_number] == 4 }[:scores_to_count]).to eq(1)
  end

  it "counts 1 best net on hole 1" do
    team = scorecard[:teams].first
    hole1 = team[:hole_scores].find { |s| s[:hole_number] == 1 }
    nets = team[:players].map { |p| p[:hole_scores].find { |s| s[:hole_number] == 1 }[:net_score] }
    expect(hole1[:team_net_strokes]).to eq(nets.min)
  end

  it "sums 2 best nets on hole 2" do
    team = scorecard[:teams].first
    hole2 = team[:hole_scores].find { |s| s[:hole_number] == 2 }
    nets = team[:players].map { |p| p[:hole_scores].find { |s| s[:hole_number] == 2 }[:net_score] }.sort
    expect(hole2[:team_net_strokes]).to eq(nets.take(2).sum)
  end

  it "sums 3 best nets on hole 3 (discards worst of four)" do
    team = scorecard[:teams].first
    hole3 = team[:hole_scores].find { |s| s[:hole_number] == 3 }
    nets = team[:players].map { |p| p[:hole_scores].find { |s| s[:hole_number] == 3 }[:net_score] }.sort
    expect(hole3[:team_net_strokes]).to eq(nets.take(3).sum)
  end

  it "computes team total net strokes when all holes complete" do
    team = scorecard[:teams].first
    expect(team[:total_net_strokes]).to eq(team[:hole_scores].sum { |s| s[:team_net_strokes] })
  end

  context "with a threesome" do
    before { gtp_dave.destroy }

    it "uses all three nets on a count-3 hole" do
      team = scorecard[:teams].first
      hole3 = team[:hole_scores].find { |s| s[:hole_number] == 3 }
      nets = team[:players].map { |p| p[:hole_scores].find { |s| s[:hole_number] == 3 }[:net_score] }
      expect(hole3[:team_net_strokes]).to eq(nets.sum)
    end
  end

  context "when a hole is missing required scores" do
    before do
      HoleScore.where(game_team_player: [ gtp_alice, gtp_bob, gtp_carol, gtp_dave ], hole_number: 2).delete_all
      HoleScore.create!(game_team_player: gtp_alice, hole_number: 2, gross_score: 5)
    end

    it "leaves hole 2 team net nil when fewer than two nets on a count-2 hole" do
      team = scorecard[:teams].first
      hole2 = team[:hole_scores].find { |s| s[:hole_number] == 2 }
      expect(hole2[:team_net_strokes]).to be_nil
    end

    it "leaves team total nil" do
      expect(scorecard[:teams].first[:total_net_strokes]).to be_nil
    end
  end

  it "includes a ranked leaderboard" do
    expect(scorecard[:leaderboard].first).to include(:rank, :team_name, :total_net_strokes)
  end
end
