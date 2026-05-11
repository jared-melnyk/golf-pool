require "rails_helper"

RSpec.describe BestBallScorecard do
  # Build a minimal game in-memory using persisted records
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
  let(:game) { Game.create!(event: event, round: round, game_type: "best_ball") }

  let(:alice) { User.create!(name: "Alice", email: "alice@test.com", password: "pw", ghin_handicap_index: 18.0) }
  let(:bob)   { User.create!(name: "Bob",   email: "bob@test.com",   password: "pw", ghin_handicap_index: 0.0) }

  let(:team_a) { GameTeam.create!(game: game, name: "Team A") }
  let(:gtp_alice) { GameTeamPlayer.create!(game_team: team_a, user: alice) }
  let(:gtp_bob)   { GameTeamPlayer.create!(game_team: team_a, user: bob) }

  before do
    # Enter gross scores: all 5s for Alice, all 4s for Bob
    (1..18).each do |h|
      HoleScore.create!(game_team_player: gtp_alice, hole_number: h, gross_score: 5)
      HoleScore.create!(game_team_player: gtp_bob,   hole_number: h, gross_score: 4)
    end
  end

  subject(:scorecard) { BestBallScorecard.new(game).call }

  # Alice: HI 18, slope 113, rating 72, par 72
  #   CH = 18 * (113/113) + (72 - 72) = 18
  #   PH = round(18 * 0.85) = round(15.3) = 15
  # Bob: HI 0 → CH 0, PH 0

  it "returns a hash with :teams key" do
    expect(scorecard).to have_key(:teams)
  end

  it "computes Alice's course handicap as 18" do
    alice_data = scorecard[:teams].first[:players].find { |p| p[:name] == "Alice" }
    expect(alice_data[:course_handicap]).to eq(18)
  end

  it "computes Alice's playing handicap as 15 (85% of 18, rounded)" do
    alice_data = scorecard[:teams].first[:players].find { |p| p[:name] == "Alice" }
    expect(alice_data[:playing_handicap]).to eq(15)
  end

  it "Bob's CH and PH are both 0" do
    bob_data = scorecard[:teams].first[:players].find { |p| p[:name] == "Bob" }
    expect(bob_data[:course_handicap]).to eq(0)
    expect(bob_data[:playing_handicap]).to eq(0)
  end

  it "computes net scores for Alice (gross - strokes received per hole)" do
    alice_data = scorecard[:teams].first[:players].find { |p| p[:name] == "Alice" }
    # PH=15: strokes on holes with stroke index 1-15 (first 15 by SI order: holes with SI 1..15)
    # hole 1 has SI 1 → stroke → net = 5-1=4; hole 2 SI 3 → stroke → net 5-1=4
    # hole with SI 16 → no stroke → net 5
    alice_net_h1 = alice_data[:hole_scores].find { |s| s[:hole_number] == 1 }[:net_score]
    expect(alice_net_h1).to eq(4)
  end

  it "computes team best-ball net per hole (min of players' net scores)" do
    team = scorecard[:teams].first
    # Hole 1: Alice net 4, Bob net 4 (no strokes) → best ball = 4
    hole1 = team[:hole_scores].find { |s| s[:hole_number] == 1 }
    expect(hole1[:best_ball_net]).to eq(4)
  end

  it "computes team total net strokes" do
    team = scorecard[:teams].first
    expect(team[:total_net_strokes]).to be_a(Integer)
  end

  it "includes leaderboard with ranked teams" do
    expect(scorecard[:leaderboard]).to be_an(Array)
    expect(scorecard[:leaderboard].first).to have_key(:rank)
    expect(scorecard[:leaderboard].first).to have_key(:team_name)
  end
end
