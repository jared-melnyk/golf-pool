require "rails_helper"

RSpec.describe HoleScore, type: :model do
  let(:user) { User.create!(name: "Bob", email: "bob@example.com", password: "password123") }
  let(:event) { Event.create!(name: "E", status: "active") }
  let(:round) do
    Round.create!(
      event: event, name: "R", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "C", tee_name: "W",
      tee_gender: "male", course_rating: 70.0, slope_rating: 115, par_total: 72,
      hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
    )
  end
  let(:game) { Game.create!(event: event, round: round, game_type: "best_ball") }
  let(:team) { GameTeam.create!(game: game, name: "Team A") }
  let(:gtp) { GameTeamPlayer.create!(game_team: team, user: user) }

  it "is valid for hole 1-18 with a gross score" do
    hs = HoleScore.new(game_team_player: gtp, hole_number: 1, gross_score: 5)
    expect(hs).to be_valid
  end

  it "is invalid for hole 0" do
    hs = HoleScore.new(game_team_player: gtp, hole_number: 0, gross_score: 4)
    expect(hs).not_to be_valid
  end

  it "is invalid for hole 19" do
    hs = HoleScore.new(game_team_player: gtp, hole_number: 19, gross_score: 4)
    expect(hs).not_to be_valid
  end

  it "allows nil gross_score (not yet entered)" do
    hs = HoleScore.new(game_team_player: gtp, hole_number: 3, gross_score: nil)
    expect(hs).to be_valid
  end

  it "enforces uniqueness of hole_number per game_team_player" do
    HoleScore.create!(game_team_player: gtp, hole_number: 5, gross_score: 4)
    dup = HoleScore.new(game_team_player: gtp, hole_number: 5, gross_score: 3)
    expect(dup).not_to be_valid
  end

  describe "forty_score pick rules" do
    let(:game) { Game.create!(event: event, round: round, game_type: "forty_score") }
    let(:team) { GameTeam.create!(game: game, name: "Foursome") }
    let(:bob_gtp) { GameTeamPlayer.create!(game_team: team, user: user) }
    let!(:extra_players) do
      %w[z1@test.com z2@test.com z3@test.com].map do |email|
        u = User.create!(name: email, email: email, password: "password123")
        GameTeamPlayer.create!(game_team: team, user: u)
      end
    end
    let(:carol_gtp) { extra_players[0] }
    let(:dave_gtp) { extra_players[1] }
    let(:ed_gtp) { extra_players[2] }

    before do
      [ bob_gtp, carol_gtp, dave_gtp, ed_gtp ].each do |p|
        (1..18).each do |h|
          HoleScore.create!(game_team_player: p, hole_number: h, gross_score: 5)
        end
      end
      HoleScore.where(game_team_player_id: bob_gtp.id).update_all(included_in_forty_score: true)
      HoleScore.where(game_team_player_id: carol_gtp.id).update_all(included_in_forty_score: true)
      (1..4).each do |h|
        HoleScore.find_by!(game_team_player_id: dave_gtp.id, hole_number: h).update_columns(included_in_forty_score: true)
      end
      # 40 counted; Ed has none
      HoleScore.where(game_team_player_id: ed_gtp.id).update_all(included_in_forty_score: false)
      HoleScore.where(game_team_player_id: dave_gtp.id).where.not(hole_number: 1..4).update_all(included_in_forty_score: false)
    end

    it "cannot mark a hole counted without gross" do
      hs = HoleScore.find_by!(game_team_player: ed_gtp, hole_number: 17)
      hs.update_columns(gross_score: nil, included_in_forty_score: false)

      hs.assign_attributes(included_in_forty_score: true)
      expect(hs).not_to be_valid
    end

    it "cannot exceed forty counted scores for the group" do
      hs = HoleScore.find_by!(game_team_player: ed_gtp, hole_number: 1)
      hs.assign_attributes(included_in_forty_score: true, gross_score: hs.gross_score)
      expect(hs).not_to be_valid
    end

    it "ignores forty pick limits for best_ball games" do
      bb_game = Game.create!(event: event, round: round, game_type: "best_ball")
      bb_team = GameTeam.create!(game: bb_game, name: "BB")
      u = User.create!(name: "solo", email: "solo@test.com", password: "password123")
      solo = GameTeamPlayer.create!(game_team: bb_team, user: u)
      HoleScore.where(game_team_player_id: solo.id).delete_all
      hs = HoleScore.create!(game_team_player: solo, hole_number: 1, gross_score: 5, included_in_forty_score: true)
      expect(hs).to be_valid
    end
  end
end
