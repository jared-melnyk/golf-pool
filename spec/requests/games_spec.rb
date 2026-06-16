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

  def create_active_game!(game_type: "best_ball")
    Game.create!(
      name: "#{game_type.titleize} at GC",
      creator: commissioner,
      status: "active",
      event: event,
      round: round,
      game_type: game_type
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
    it "creates a draft game and redirects to setup" do
      expect {
        post event_games_path(event), params: { game: { name: "Saturday best ball" } }
      }.to change(Game, :count).by(1)

      game = Game.last
      expect(game.status).to eq("draft")
      expect(game.event).to eq(event)
      expect(response).to redirect_to(game_setup_path(game))
    end
  end

  describe "GET /games/:token" do
    let(:game) { create_active_game! }

    it "renders the scorecard page" do
      get game_path(game)
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
        get game_path(game)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Team Alpha")
      end

      it "shows invite button and finalize scores for managers" do
        get game_path(game)
        expect(response.body).to include("Invite players")
        expect(response.body).to include("Finalize scores")
        expect(response.body).not_to include("Complete game")
      end
    end

    context "40 Score with the same players on two teams" do
      let(:game) { create_active_game!(game_type: "forty_score") }
      let(:player1) { User.create!(name: "Alice", email: "alice2@test.com", password: "pw", ghin_handicap_index: 10.0) }
      let(:player2) { User.create!(name: "Bob", email: "bob2@test.com", password: "pw", ghin_handicap_index: 12.0) }
      let(:player3) { User.create!(name: "Cara", email: "cara2@test.com", password: "pw", ghin_handicap_index: 14.0) }
      let!(:team_a) { GameTeam.create!(game: game, name: "Group A") }
      let!(:team_b) { GameTeam.create!(game: game, name: "Group B") }

      before do
        [ player1, player2, player3 ].each do |u|
          EventMembership.create!(event: event, user: u, role: "player")
          GameTeamPlayer.create!(game_team: team_a, user: u)
          GameTeamPlayer.create!(game_team: team_b, user: u)
        end
      end

      it "renders distinct gross score field ids per team for the same player name" do
        get game_path(game)

        gtp_a = GameTeamPlayer.find_by!(game_team: team_a, user: player1)
        gtp_b = GameTeamPlayer.find_by!(game_team: team_b, user: player1)
        id_a = ActionView::RecordIdentifier.dom_id(gtp_a, "gross_hole_1")
        id_b = ActionView::RecordIdentifier.dom_id(gtp_b, "gross_hole_1")

        expect(id_a).not_to eq(id_b)
        expect(response.body.scan(id_a).size).to eq(1)
        expect(response.body.scan(id_b).size).to eq(1)
      end
    end
  end

  describe "GET /games/:token/edit_teams" do
    let(:game) { create_active_game! }

    it "renders edit_teams for managers" do
      get edit_teams_game_path(game)
      expect(response).to have_http_status(:ok)
    end

    it "redirects non-managers" do
      player = User.create!(name: "Player", email: "player@test.com", password: "pw")
      EventMembership.create!(event: event, user: player, role: "player")
      post login_path, params: { email: player.email, password: "pw" }
      get edit_teams_game_path(game)
      expect(response).to redirect_to(game_path(game))
    end
  end

  describe "PATCH /games/:token/update_teams" do
    let(:game) { create_active_game! }
    let(:player1) { User.create!(name: "P1", email: "p1@test.com", password: "pw") }
    let(:player2) { User.create!(name: "P2", email: "p2@test.com", password: "pw") }

    before do
      EventMembership.create!(event: event, user: player1, role: "player")
      EventMembership.create!(event: event, user: player2, role: "player")
    end

    it "creates teams from params and redirects to game show" do
      patch update_teams_game_path(game), params: {
        teams: {
          "0" => { name: "Team A", user_ids: [ player1.id.to_s ] },
          "1" => { name: "Team B", user_ids: [ player2.id.to_s ] }
        }
      }
      expect(response).to redirect_to(game_path(game))
      expect(game.game_teams.reload.map(&:name)).to match_array([ "Team A", "Team B" ])
    end

    it "skips blank team names and redirects to game show" do
      patch update_teams_game_path(game), params: {
        teams: { "0" => { name: "" } }
      }
      expect(response).to redirect_to(game_path(game))
      expect(game.game_teams.reload).to be_empty
    end

    context "when game type is forty_score" do
      let(:game) { create_active_game!(game_type: "forty_score") }
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
        patch update_teams_game_path(game), params: {
          teams: {
            "0" => {
              name: "Cart 1",
              user_ids: [ p1.id, p2.id, p3.id, p4.id ].map(&:to_s)
            }
          }
        }
        expect(response).to redirect_to(game_path(game))
        expect(game.game_teams.reload.sole.game_team_players.size).to eq(4)
      end

      it "accepts a threesome of three players" do
        patch update_teams_game_path(game), params: {
          teams: {
            "0" => {
              name: "Threesome",
              user_ids: [ p1.id, p2.id, p3.id ].map(&:to_s)
            }
          }
        }
        expect(response).to redirect_to(game_path(game))
        expect(game.game_teams.reload.sole.game_team_players.size).to eq(3)
      end

      it "rejects a group with only two golfers" do
        patch update_teams_game_path(game), params: {
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

    context "when game type is cha_cha_cha" do
      let(:game) { create_active_game!(game_type: "cha_cha_cha") }
      let(:p1) { User.create!(name: "Cc1", email: "cc1@test.com", password: "pw") }
      let(:p2) { User.create!(name: "Cc2", email: "cc2@test.com", password: "pw") }
      let(:p3) { User.create!(name: "Cc3", email: "cc3@test.com", password: "pw") }
      let(:p4) { User.create!(name: "Cc4", email: "cc4@test.com", password: "pw") }

      before do
        [ p1, p2, p3, p4 ].each do |pl|
          EventMembership.create!(event: event, user: pl, role: "player")
        end
      end

      it "accepts a threesome" do
        patch update_teams_game_path(game), params: {
          teams: { "0" => { name: "Trio", user_ids: [ p1.id, p2.id, p3.id ].map(&:to_s) } }
        }
        expect(response).to redirect_to(game_path(game))
        expect(game.game_teams.reload.sole.game_team_players.size).to eq(3)
      end

      it "rejects a twosome" do
        patch update_teams_game_path(game), params: {
          teams: { "0" => { name: "Pair", user_ids: [ p1.id, p2.id ].map(&:to_s) } }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(game.game_teams.reload).to be_empty
      end
    end

    context "when game type is vegas" do
      let(:game) { create_active_game!(game_type: "vegas") }
      let(:p1) { User.create!(name: "V1", email: "v1@test.com", password: "pw") }
      let(:p2) { User.create!(name: "V2", email: "v2@test.com", password: "pw") }
      let(:p3) { User.create!(name: "V3", email: "v3@test.com", password: "pw") }
      let(:p4) { User.create!(name: "V4", email: "v4@test.com", password: "pw") }

      before do
        [ p1, p2, p3, p4 ].each do |pl|
          EventMembership.create!(event: event, user: pl, role: "player")
        end
      end

      it "accepts two teams of two" do
        patch update_teams_game_path(game), params: {
          teams: {
            "0" => { name: "Team A", user_ids: [ p1.id, p2.id ].map(&:to_s) },
            "1" => { name: "Team B", user_ids: [ p3.id, p4.id ].map(&:to_s) }
          }
        }
        expect(response).to redirect_to(game_path(game))
        expect(game.game_teams.reload.count).to eq(2)
        expect(game.game_teams.map { |t| t.game_team_players.size }).to eq([ 2, 2 ])
      end

      it "rejects a single team of four" do
        patch update_teams_game_path(game), params: {
          teams: {
            "0" => { name: "Foursome", user_ids: [ p1.id, p2.id, p3.id, p4.id ].map(&:to_s) }
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(game.game_teams.reload).to be_empty
      end

      it "rejects teams with three players" do
        patch update_teams_game_path(game), params: {
          teams: {
            "0" => { name: "Team A", user_ids: [ p1.id, p2.id, p3.id ].map(&:to_s) },
            "1" => { name: "Team B", user_ids: [ p4.id ].map(&:to_s) }
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(game.game_teams.reload).to be_empty
      end
    end
  end

  describe "POST /games/:token/join" do
    let(:host) { User.create!(name: "H", email: "h@test.com", password: "pw") }
    let(:player) { User.create!(name: "P", email: "p@test.com", password: "pw") }
    let(:game) do
      g = Game.create!(
        name: "Ad hoc",
        creator: host,
        status: "active",
        round: round,
        game_type: "best_ball"
      )
      GameMembership.create!(game: g, user: host, role: "host")
      g
    end

    it "adds player membership to ad hoc game" do
      post login_path, params: { email: player.email, password: "pw" }
      post join_game_path(game)
      expect(game.members).to include(player)
      expect(response).to redirect_to(game_path(game))
    end
  end
end
