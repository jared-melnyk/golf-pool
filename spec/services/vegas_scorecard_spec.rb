# frozen_string_literal: true

require "rails_helper"

RSpec.describe VegasScorecard do
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
  let(:game) { create_test_game!(event: event, round: round, game_type: "vegas") }

  let(:alice) { User.create!(name: "Alice", email: "alice-vegas@test.com", password: "pw", ghin_handicap_index: 0.0) }
  let(:bob)   { User.create!(name: "Bob",   email: "bob-vegas@test.com",   password: "pw", ghin_handicap_index: 0.0) }
  let(:carol) { User.create!(name: "Carol", email: "carol-vegas@test.com", password: "pw", ghin_handicap_index: 0.0) }
  let(:dave)  { User.create!(name: "Dave",  email: "dave-vegas@test.com",  password: "pw", ghin_handicap_index: 0.0) }

  let(:team_a) { GameTeam.create!(game: game, name: "Team A") }
  let(:team_b) { GameTeam.create!(game: game, name: "Team B") }
  let(:gtp_alice) { GameTeamPlayer.create!(game_team: team_a, user: alice) }
  let(:gtp_bob)   { GameTeamPlayer.create!(game_team: team_a, user: bob) }
  let(:gtp_carol) { GameTeamPlayer.create!(game_team: team_b, user: carol) }
  let(:gtp_dave)  { GameTeamPlayer.create!(game_team: team_b, user: dave) }

  def score_hole(hole, scores)
    HoleScore.create!(game_team_player: gtp_alice, hole_number: hole, gross_score: scores[:alice])
    HoleScore.create!(game_team_player: gtp_bob,   hole_number: hole, gross_score: scores[:bob])
    HoleScore.create!(game_team_player: gtp_carol, hole_number: hole, gross_score: scores[:carol])
    HoleScore.create!(game_team_player: gtp_dave,  hole_number: hole, gross_score: scores[:dave])
  end

  subject(:scorecard) { VegasScorecard.new(game).call }

  it "uses 100% playing handicap allowance" do
    expect(game.playing_handicap_allowance_percent).to eq(100)
  end

  describe "basic hole win (design §5.1)" do
    before { score_hole(1, alice: 4, bob: 5, carol: 5, dave: 7) }

    it "computes team numbers and hole points" do
      hole = scorecard[:holes].find { |h| h[:hole_number] == 1 }
      expect(hole[:team_numbers][team_a.id]).to eq(45)
      expect(hole[:team_numbers][team_b.id]).to eq(57)
      expect(hole[:hole_points]).to eq(12)
      expect(hole[:running_wash]).to eq(12)
    end
  end

  describe "tie on hole (design §5.2)" do
    before { score_hole(1, alice: 4, bob: 4, carol: 4, dave: 4) }

    it "awards zero points" do
      hole = scorecard[:holes].find { |h| h[:hole_number] == 1 }
      expect(hole[:team_numbers][team_a.id]).to eq(44)
      expect(hole[:team_numbers][team_b.id]).to eq(44)
      expect(hole[:hole_points]).to eq(0)
      expect(hole[:running_wash]).to eq(0)
    end
  end

  describe "net cap (design §5.3)" do
    before { score_hole(1, alice: 8, bob: 10, carol: 5, dave: 6) }

    it "caps nets above 9 before pairing" do
      hole = scorecard[:holes].find { |h| h[:hole_number] == 1 }
      expect(hole[:team_numbers][team_a.id]).to eq(89)
      expect(hole[:team_numbers][team_b.id]).to eq(56)
      expect(hole[:hole_points]).to eq(-33)
    end
  end

  describe "birdie flip (design §3.4 example)" do
    before { score_hole(1, alice: 4, bob: 5, carol: 3, dave: 5) }

    it "flips opponent digits when a team birdies" do
      hole = scorecard[:holes].find { |h| h[:hole_number] == 1 }
      expect(hole[:team_numbers][team_a.id]).to eq(54)
      expect(hole[:team_numbers][team_b.id]).to eq(35)
      expect(hole[:flipped_team_ids]).to eq([ team_a.id ])
      expect(hole[:birdie_team_ids]).to eq([ team_b.id ])
      expect(hole[:hole_points]).to eq(-19)
    end
  end

  describe "both teams birdie (design §5.4)" do
    before { score_hole(1, alice: 3, bob: 5, carol: 3, dave: 4) }

    it "applies both flips" do
      hole = scorecard[:holes].find { |h| h[:hole_number] == 1 }
      expect(hole[:team_numbers][team_a.id]).to eq(53)
      expect(hole[:team_numbers][team_b.id]).to eq(43)
      expect(hole[:hole_points]).to eq(-10)
    end
  end

  describe "running wash" do
    before do
      score_hole(1, alice: 4, bob: 5, carol: 5, dave: 7)
      score_hole(2, alice: 5, bob: 5, carol: 4, dave: 7)
      score_hole(3, alice: 4, bob: 4, carol: 4, dave: 4)
    end

    it "accumulates hole points from reference team perspective" do
      holes = scorecard[:holes]
      expect(holes.find { |h| h[:hole_number] == 1 }[:running_wash]).to eq(12)
      expect(holes.find { |h| h[:hole_number] == 2 }[:running_wash]).to eq(4)
      expect(holes.find { |h| h[:hole_number] == 3 }[:running_wash]).to eq(4)
    end

    it "builds wash summary" do
      expect(scorecard[:wash][:margin]).to eq(4)
      expect(scorecard[:wash][:leader_name]).to eq("Team A")
      expect(scorecard[:wash][:label]).to eq("Team A leads by 4")
    end
  end

  context "when a hole is incomplete" do
    before do
      score_hole(1, alice: 4, bob: 5, carol: 5, dave: 7)
      HoleScore.create!(game_team_player: gtp_alice, hole_number: 2, gross_score: 4)
    end

    it "skips incomplete holes" do
      hole2 = scorecard[:holes].find { |h| h[:hole_number] == 2 }
      expect(hole2[:complete]).to be(false)
      expect(hole2[:hole_points]).to be_nil
      expect(hole2[:running_wash]).to be_nil
    end

    it "wash reflects only complete holes" do
      expect(scorecard[:wash][:margin]).to eq(12)
      expect(scorecard[:wash][:label]).to eq("Team A leads by 12")
    end
  end
end
