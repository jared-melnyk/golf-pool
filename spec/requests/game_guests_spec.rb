# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Game guests", type: :request do
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
  let(:game) do
    Game.create!(
      name: "Best Ball at GC",
      creator: commissioner,
      status: "active",
      event: event,
      round: round,
      game_type: "best_ball"
    )
  end

  before { post login_path, params: { email: commissioner.email, password: "pw" } }

  describe "POST /games/:token/game_guests" do
    it "creates a guest and redirects to edit teams" do
      expect {
        post game_game_guests_path(game), params: {
          game_guest: { name: "Jon", handicap_index: "14.2" }
        }
      }.to change(GameGuest, :count).by(1)

      guest = GameGuest.last
      expect(guest.name).to eq("Jon")
      expect(guest.handicap_index).to eq(14.2)
      expect(response).to redirect_to(edit_teams_game_path(game))
    end

    it "rejects missing handicap index" do
      expect {
        post game_game_guests_path(game), params: {
          game_guest: { name: "Jon", handicap_index: "" }
        }
      }.not_to change(GameGuest, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects non-managers" do
      player = User.create!(name: "Player", email: "player@test.com", password: "pw")
      EventMembership.create!(event: event, user: player, role: "player")
      post login_path, params: { email: player.email, password: "pw" }

      expect {
        post game_game_guests_path(game), params: {
          game_guest: { name: "Jon", handicap_index: "10" }
        }
      }.not_to change(GameGuest, :count)

      expect(response).to redirect_to(game_path(game))
    end
  end

  describe "DELETE /games/:token/game_guests/:id" do
    let!(:guest) { GameGuest.create!(game: game, name: "Jon", handicap_index: 14.2) }

    it "destroys the guest and redirects to edit teams" do
      expect {
        delete game_game_guest_path(game, guest)
      }.to change(GameGuest, :count).by(-1)

      expect(response).to redirect_to(edit_teams_game_path(game))
    end

    it "removes team assignment when destroying an assigned guest" do
      team = GameTeam.create!(game: game, name: "Team A")
      GameTeamPlayer.create!(game_team: team, game_guest: guest)

      expect {
        delete game_game_guest_path(game, guest)
      }.to change(GameTeamPlayer, :count).by(-1)

      expect(GameGuest.find_by(id: guest.id)).to be_nil
    end
  end

  describe "PATCH /games/:token/update_teams with guests" do
    let(:player) { User.create!(name: "P1", email: "p1@test.com", password: "pw") }
    let!(:guest) { GameGuest.create!(game: game, name: "Jon", handicap_index: 12.0) }

    before do
      EventMembership.create!(event: event, user: player, role: "player")
    end

    it "assigns users and guests to teams" do
      patch update_teams_game_path(game), params: {
        teams: {
          "0" => { name: "Team A", user_ids: [ player.id.to_s ], guest_ids: [ guest.id.to_s ] },
          "1" => { name: "Team B", user_ids: [], guest_ids: [] }
        }
      }

      expect(response).to redirect_to(game_path(game))
      team_a = game.game_teams.find_by!(name: "Team A")
      expect(team_a.game_team_players.map(&:display_name)).to match_array([ "P1", "Jon" ])
    end

    it "saves guest teams even when team names are left blank" do
      guest2 = GameGuest.create!(game: game, name: "Stu", handicap_index: 18.0)

      patch update_teams_game_path(game), params: {
        teams: {
          "0" => { name: "", guest_ids: [ guest.id.to_s ] },
          "1" => { name: "", guest_ids: [ guest2.id.to_s ] }
        }
      }

      expect(response).to redirect_to(game_path(game))
      expect(game.game_teams.reload.map(&:name)).to match_array([ "Team A", "Team B" ])
      expect(game.game_teams.flat_map { |t| t.game_team_players.map(&:display_name) }).to match_array([ "Jon", "Stu" ])
    end

    it "leaves unchecked guests on the roster but not on a team" do
      patch update_teams_game_path(game), params: {
        teams: {
          "0" => { name: "Team A", user_ids: [ player.id.to_s ], guest_ids: [] }
        }
      }

      expect(response).to redirect_to(game_path(game))
      expect(game.game_guests.reload).to include(guest)
      expect(GameTeamPlayer.where(game_guest: guest)).to be_empty
    end
  end

  describe "ad-hoc host game history with guests" do
    let(:host) { User.create!(name: "Host", email: "host@test.com", password: "pw") }
    let(:ad_hoc_game) do
      g = Game.create!(name: "Quick round", creator: host, status: "completed", round: round, game_type: "best_ball")
      g.game_memberships.create!(user: host, role: "host")
      guest = GameGuest.create!(game: g, name: "Stu", handicap_index: 16.0)
      team = GameTeam.create!(game: g, name: "Team A")
      GameTeamPlayer.create!(game_team: team, user: host)
      GameTeamPlayer.create!(game_team: team, game_guest: guest)
      g
    end

    before do
      post login_path, params: { email: host.email, password: "pw" }
      ad_hoc_game
    end

    it "lists the game for the host after completion" do
      get games_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Quick round")
    end
  end

  describe "GET /games/:token scorecard with guests" do
    let!(:guest) { GameGuest.create!(game: game, name: "Kathy", handicap_index: 20.0) }

    before do
      team = GameTeam.create!(game: game, name: "Team Alpha")
      GameTeamPlayer.create!(game_team: team, game_guest: guest)
    end

    it "shows the guest name on the scorecard" do
      get game_path(game)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Kathy")
    end
  end
end
