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
    # Alice PH=15, hole 1 SI=1 → Alice gets a stroke → Alice net = 5-1 = 4
    # Bob PH=0 → no strokes → Bob net = 4-0 = 4
    # Both are 4 here. Check hole with SI 17 (index 16, hole 9 in our layout):
    # Hole 9 has SI=17 which is > Alice's PH=15, so Alice gets no stroke on hole 9
    # Alice net on hole 9 = 5 (no stroke), Bob net on hole 9 = 4 (gross 4, no strokes)
    # Best ball should be 4 (Bob's)
    hole9 = team[:hole_scores].find { |s| s[:hole_number] == 9 }
    expect(hole9[:best_ball_net]).to eq(4)

    # Also verify a hole where Alice's stroke DOES make her best: hole 1 SI=1
    # Alice gross=5, PH=15, SI=1 ≤ 15 → net=4. Bob gross=4, no strokes → net=4
    # Best ball = 4 (tied, still min)
    hole1 = team[:hole_scores].find { |s| s[:hole_number] == 1 }
    expect(hole1[:best_ball_net]).to eq(4)
  end

  it "picks the better net score when players' nets differ on a hole" do
    # Hole 9 in our round layout: hole_handicap=17, so Alice (PH=15) gets no stroke
    # Alice gross=5, net=5. Bob gross=4, net=4 (no strokes). Best ball should be 4 (Bob's).
    team = scorecard[:teams].first
    alice_data = team[:players].find { |p| p[:name] == "Alice" }
    bob_data   = team[:players].find { |p| p[:name] == "Bob" }
    alice_hole9_net = alice_data[:hole_scores].find { |s| s[:hole_number] == 9 }[:net_score]
    bob_hole9_net   = bob_data[:hole_scores].find { |s| s[:hole_number] == 9 }[:net_score]
    hole9_best = team[:hole_scores].find { |s| s[:hole_number] == 9 }[:best_ball_net]

    expect(alice_hole9_net).to eq(5)  # no stroke on SI=17 with PH=15
    expect(bob_hole9_net).to eq(4)    # gross 4, no strokes
    expect(hole9_best).to eq(4)       # best ball picks Bob's 4
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
