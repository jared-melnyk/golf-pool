# frozen_string_literal: true

require "rails_helper"

RSpec.describe "HoleScores", type: :request do
  let(:commissioner) { User.create!(name: "Comm", email: "comm-fs@test.com", password: "pw") }
  let(:event) { Event.create!(name: "Out", status: "active") }
  let!(:commissioner_membership) { EventMembership.create!(event: event, user: commissioner, role: "commissioner") }
  let(:round) do
    Round.create!(
      event: event, name: "R", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "C", tee_name: "Blue",
      tee_gender: "male", course_rating: 72.0, slope_rating: 113, par_total: 72,
      hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
    )
  end
  let(:game) do
    Game.create!(
      name: "40 Score at C",
      creator: commissioner,
      status: "active",
      event: event,
      round: round,
      game_type: "forty_score"
    )
  end
  let(:team) { GameTeam.create!(game: game, name: "Foursome") }
  let(:alice) { User.create!(name: "Pa", email: "pa@test.com", password: "pw") }
  let(:bob) { User.create!(name: "Pb", email: "pb@test.com", password: "pw") }
  let(:cindy) { User.create!(name: "Pc", email: "pc@test.com", password: "pw") }
  let(:dan) { User.create!(name: "Pd", email: "pd@test.com", password: "pw") }
  let!(:gtp_alice) { GameTeamPlayer.create!(game_team: team, user: alice) }
  let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

  before do
    [ alice, bob, cindy, dan ].each do |u|
      EventMembership.create!(event: event, user: u, role: "player")
      GameTeamPlayer.create!(game_team: team, user: u) unless u == alice
    end
    team.reload.game_team_players.each do |gtp|
      HoleScore.find_or_create_by!(game_team_player: gtp, hole_number: 1) { |s| s.gross_score = 4 }
    end
    post login_path, params: { email: bob.email, password: "pw" }
  end

  describe "40 Score" do
    it "lets a teammate toggle another golfer's forty pick via turbo stream" do
      patch game_hole_score_path(game, gtp_alice),
            params: { hole_number: 1, forty_pick_only: "1", included_in_forty_score: "1" },
            headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq Mime[:turbo_stream]
      expect(response.body).to include("turbo-stream")
      expect(HoleScore.find_by!(game_team_player_id: gtp_alice.id, hole_number: 1).included_in_forty_score).to be(true)
    end

    it "updates gross score via turbo stream without redirecting" do
      gtp_bob = GameTeamPlayer.find_by!(game_team: team, user: bob)
      patch game_hole_score_path(game, gtp_bob),
            params: { hole_number: 2, gross_score: "5" },
            headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq Mime[:turbo_stream]
      expect(response).not_to be_redirect
      expect(HoleScore.find_by!(game_team_player_id: gtp_bob.id, hole_number: 2).gross_score).to eq(5)
    end

    it "lets a teammate enter another golfer's gross score via turbo stream" do
      patch game_hole_score_path(game, gtp_alice),
            params: { hole_number: 3, gross_score: "6" },
            headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq Mime[:turbo_stream]
      expect(HoleScore.find_by!(game_team_player_id: gtp_alice.id, hole_number: 3).gross_score).to eq(6)
    end

    it "rejects score entry from a player on a different team" do
      other_team = GameTeam.create!(game: game, name: "Other")
      outsider = User.create!(name: "Out", email: "out@test.com", password: "pw")
      EventMembership.create!(event: event, user: outsider, role: "player")
      GameTeamPlayer.create!(game_team: other_team, user: outsider)

      delete logout_path
      post login_path, params: { email: outsider.email, password: "pw" }

      patch game_hole_score_path(game, gtp_alice),
            params: { hole_number: 4, gross_score: "5" }

      expect(response).to redirect_to(game_path(game))
      follow_redirect!
      expect(response.body).to include("You can only enter scores for your own team.")
      expect(HoleScore.find_by(game_team_player_id: gtp_alice.id, hole_number: 4)).to be_nil
    end
  end

  describe "Best Ball" do
    let(:game) do
      Game.create!(
        name: "Best Ball at C",
        creator: commissioner,
        status: "active",
        event: event,
        round: round,
        game_type: "best_ball"
      )
    end
    let!(:gtp_bob) { GameTeamPlayer.find_by!(game_team: team, user: bob) }

    it "updates gross score via turbo stream" do
      patch game_hole_score_path(game, gtp_bob),
            params: { hole_number: 1, gross_score: "6" },
            headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq Mime[:turbo_stream]
      expect(response.body).to include("net_hole_1")
      expect(HoleScore.find_by!(game_team_player_id: gtp_bob.id, hole_number: 1).gross_score).to eq(6)
    end
  end
end
