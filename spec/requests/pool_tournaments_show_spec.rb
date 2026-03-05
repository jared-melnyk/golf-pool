require "rails_helper"

RSpec.describe "PoolTournament scores", type: :request do
  let(:creator) { User.create!(email: "creator@example.com", name: "Creator", password: "password") }
  let(:member) { User.create!(email: "member@example.com", name: "Member", password: "password") }
  let(:pool) { Pool.create!(name: "Test Pool", creator: creator) }
  let!(:pool_user_creator) { PoolUser.create!(pool: pool, user: creator) }
  let!(:pool_user_member) { PoolUser.create!(pool: pool, user: member) }
  let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.ago, ends_at: 1.day.from_now, external_id: "20") }
  let(:pool_tournament) { PoolTournament.create!(pool: pool, tournament: tournament) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
  end

  describe "GET /pools/:pool_token/pool_tournaments/:id" do
    let(:current_user) { member }

    it "requires membership in the pool" do
      other_user = User.create!(email: "other@example.com", name: "Other", password: "password")
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(other_user)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to redirect_to(pool)
      follow_redirect!
      expect(response.body).to include("You must be a member of this pool to view scores.")
    end

    it "renders successfully for a pool member" do
      client = instance_double(BallDontLie::Client, fetch_all_player_round_results: [])
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Live scores are temporarily unavailable").or include(pool.name)
    end
  end
end
