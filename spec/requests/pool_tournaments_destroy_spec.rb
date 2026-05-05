require "rails_helper"

RSpec.describe "PoolTournaments destroy", type: :request do
  let(:creator) { User.create!(email: "creator@example.com", name: "Creator", password: "password") }
  let(:member) { User.create!(email: "member@example.com", name: "Member", password: "password") }
  let(:pool) { Pool.create!(name: "Test Pool", creator: creator) }
  let!(:pool_user_creator) { PoolUser.create!(pool: pool, user: creator) }
  let!(:pool_user_member) { PoolUser.create!(pool: pool, user: member) }
  let(:tournament) do
    Tournament.create!(
      name: "Completed Event",
      starts_at: 4.days.ago,
      ends_at: 2.days.ago
    )
  end
  let!(:pool_tournament) { PoolTournament.create!(pool: pool, tournament: tournament) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
  end

  describe "DELETE /pools/:pool_token/pool_tournaments/:id" do
    context "as commissioner" do
      let(:current_user) { creator }

      it "allows removing a completed tournament from the pool" do
        winner = Golfer.create!(name: "Winner", external_id: "999")
        tournament.update!(champion_golfer: winner)

        expect do
          delete pool_pool_tournament_path(pool, pool_tournament)
        end.to change(PoolTournament, :count).by(-1)

        expect(response).to redirect_to(pool)
        follow_redirect!
        expect(response.body).to include("Tournament removed from pool.")
      end
    end

    context "as non-commissioner" do
      let(:current_user) { member }

      it "denies removal" do
        winner = Golfer.create!(name: "Winner 2", external_id: "998")
        tournament.update!(champion_golfer: winner)

        expect do
          delete pool_pool_tournament_path(pool, pool_tournament)
        end.not_to change(PoolTournament, :count)

        expect(response).to redirect_to(pool)
        follow_redirect!
        expect(response.body).to include("Only the pool creator can add or remove tournaments.")
      end
    end
  end
end
