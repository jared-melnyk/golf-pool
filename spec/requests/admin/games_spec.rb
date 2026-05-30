# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Games", type: :request do
  let(:admin) { User.create!(name: "Admin", email: "admin@example.com", password: "password", admin: true) }

  before { post login_path, params: { email: admin.email, password: "password" } }

  describe "GET /admin/games" do
    it "returns success for an admin" do
      get admin_games_path
      expect(response).to have_http_status(:ok)
    end

    it "lists all games, including those not visible to the admin" do
      creator = User.create!(name: "Creator", email: "creator@example.com", password: "password")
      visible = Game.create!(name: "Visible Game", creator: admin, status: "draft")
      GameMembership.create!(game: visible, user: admin, role: "host")
      hidden = Game.create!(name: "Hidden Game", creator: creator, status: "draft")

      get admin_games_path

      expect(response.body).to include("Visible Game")
      expect(response.body).to include("Hidden Game")
    end

    it "shows game details in the table" do
      creator = User.create!(name: "Host", email: "host@example.com", password: "password")
      Game.create!(
        name: "Saturday Best Ball",
        creator: creator,
        status: "draft",
        game_type: "best_ball"
      )

      get admin_games_path

      expect(response.body).to include("Saturday Best Ball")
      expect(response.body).to include("Draft")
      expect(response.body).to include("Best Ball")
      expect(response.body).to include("Host")
      expect(response.body).to include("Ad hoc")
    end
  end

  describe "authorization" do
    let(:member) { User.create!(name: "Member", email: "member@example.com", password: "password", admin: false) }

    before { post login_path, params: { email: member.email, password: "password" } }

    it "redirects non-admin from games index" do
      get admin_games_path
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(flash[:alert]).to eq("Not authorized.")
    end
  end
end
