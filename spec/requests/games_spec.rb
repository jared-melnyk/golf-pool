# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Games", type: :request do
  let(:commissioner) { User.create!(name: "Comm", email: "comm@test.com", password: "pw") }
  let(:event) { Event.create!(name: "Outing", status: "active") }
  let!(:membership) { EventMembership.create!(event: event, user: commissioner, role: "commissioner") }
  let(:round) do
    Round.create!(
      event: event, name: "Morning", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "GC", tee_name: "Blue",
      tee_gender: "male", course_rating: 72.0, slope_rating: 128, par_total: 72,
      hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
    )
  end

  before { post login_path, params: { email: commissioner.email, password: "pw" } }

  describe "GET /events/:event_token/games/new" do
    it "renders new game form for commissioners" do
      get new_event_game_path(event)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /events/:event_token/games" do
    it "creates a game and redirects to edit_teams" do
      expect {
        post event_games_path(event), params: { game: { round_id: round.id, game_type: "best_ball" } }
      }.to change(Game, :count).by(1)
      expect(response).to redirect_to(edit_teams_event_game_path(event, Game.last))
    end

    it "creates a forty_score game" do
      expect {
        post event_games_path(event), params: { game: { round_id: round.id, game_type: "forty_score" } }
      }.to change(Game, :count).by(1)
      expect(Game.last.game_type).to eq("forty_score")
      expect(response).to redirect_to(edit_teams_event_game_path(event, Game.last))
    end
  end

  describe "GET /events/:event_token/games/:id" do
    let(:game) { Game.create!(event: event, round: round, game_type: "best_ball") }

    it "renders the scorecard page" do
      get event_game_path(event, game)
      expect(response).to have_http_status(:ok)
    end

    context "with teams set up" do
      let(:player1) { User.create!(name: "Alice", email: "alice@test.com", password: "pw", ghin_handicap_index: 18.0) }
      let(:player2) { User.create!(name: "Bob", email: "bob@test.com", password: "pw", ghin_handicap_index: 0.0) }

      before do
        EventMembership.create!(event: event, user: player1, role: "player")
        EventMembership.create!(event: event, user: player2, role: "player")
        team = GameTeam.create!(game: game, name: "Team Alpha")
        GameTeamPlayer.create!(game_team: team, user: player1)
        GameTeamPlayer.create!(game_team: team, user: player2)
      end

      it "renders scorecard with team name" do
        get event_game_path(event, game)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Team Alpha")
      end
    end
  end

  describe "GET /events/:event_token/games/:id/edit_teams" do
    let(:game) { Game.create!(event: event, round: round, game_type: "best_ball") }

    it "renders edit_teams for commissioners" do
      get edit_teams_event_game_path(event, game)
      expect(response).to have_http_status(:ok)
    end

    it "redirects non-commissioners back to event" do
      player = User.create!(name: "Player", email: "player@test.com", password: "pw")
      EventMembership.create!(event: event, user: player, role: "player")
      post login_path, params: { email: player.email, password: "pw" }
      get edit_teams_event_game_path(event, game)
      expect(response).to redirect_to(event_path(event))
    end
  end

  describe "PATCH /events/:event_token/games/:id/update_teams" do
    let(:game) { Game.create!(event: event, round: round, game_type: "best_ball") }
    let(:player1) { User.create!(name: "P1", email: "p1@test.com", password: "pw") }
    let(:player2) { User.create!(name: "P2", email: "p2@test.com", password: "pw") }

    before do
      EventMembership.create!(event: event, user: player1, role: "player")
      EventMembership.create!(event: event, user: player2, role: "player")
    end

    it "creates teams from params and redirects to game show" do
      patch update_teams_event_game_path(event, game), params: {
        teams: {
          "0" => { name: "Team A", user_ids: [ player1.id.to_s ] },
          "1" => { name: "Team B", user_ids: [ player2.id.to_s ] }
        }
      }
      expect(response).to redirect_to(event_game_path(event, game))
      expect(game.game_teams.reload.map(&:name)).to match_array([ "Team A", "Team B" ])
    end

    it "skips blank team names and redirects to game show" do
      patch update_teams_event_game_path(event, game), params: {
        teams: { "0" => { name: "" } }
      }
      expect(response).to redirect_to(event_game_path(event, game))
      expect(game.game_teams.reload).to be_empty
    end

    context "when game type is forty_score" do
      let(:game) { Game.create!(event: event, round: round, game_type: "forty_score") }
      let(:p1) { User.create!(name: "Fs1", email: "fs1@test.com", password: "pw") }
      let(:p2) { User.create!(name: "Fs2", email: "fs2@test.com", password: "pw") }
      let(:p3) { User.create!(name: "Fs3", email: "fs3@test.com", password: "pw") }
      let(:p4) { User.create!(name: "Fs4", email: "fs4@test.com", password: "pw") }
      let(:p5) { User.create!(name: "Fs5", email: "fs5@test.com", password: "pw") }

      before do
        [ p1, p2, p3, p4, p5 ].each do |pl|
          EventMembership.create!(event: event, user: pl, role: "player")
        end
      end

      it "accepts a foursome of four players" do
        patch update_teams_event_game_path(event, game), params: {
          teams: {
            "0" => {
              name: "Cart 1",
              user_ids: [ p1.id, p2.id, p3.id, p4.id ].map(&:to_s)
            }
          }
        }
        expect(response).to redirect_to(event_game_path(event, game))
        expect(game.game_teams.reload.sole.game_team_players.size).to eq(4)
      end

      it "rejects a group without exactly four golfers" do
        patch update_teams_event_game_path(event, game), params: {
          teams: {
            "0" => {
              name: "Incomplete",
              user_ids: [ p1.id, p2.id ].map(&:to_s)
            }
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(game.game_teams.reload).to be_empty
      end
    end
  end
end
