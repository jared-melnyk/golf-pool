require "rails_helper"

RSpec.describe "Pools show", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:creator) { User.create!(email: "creator@example.com", name: "Creator", password: "password") }
  let(:member) { User.create!(email: "member@example.com", name: "Member", password: "password") }
  let(:pool) { Pool.create!(name: "Test Pool", creator: creator) }

  let!(:creator_pool_user) { PoolUser.create!(pool: pool, user: creator) }
  let!(:member_pool_user) { PoolUser.create!(pool: pool, user: member) }

  let(:starts_at) { 2.days.from_now.change(usec: 0) }
  let(:tournament) { Tournament.create!(name: "Event", starts_at: starts_at) }
  let!(:pool_tournament) { PoolTournament.create!(pool: pool, tournament: tournament) }

  before do
    # Simple sign-in helper: app uses current_user from ApplicationController, so
    # we simulate it by stubbing in tests.
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(creator)
  end

  it "assigns picks for all pool members indexed by tournament and user" do
    creator_pick = Pick.create!(user: creator, pool_tournament: pool_tournament)
    member_pick = Pick.create!(user: member, pool_tournament: pool_tournament)

    get pool_path(pool)

    expect(response).to have_http_status(:ok)

    # Use controller instance variable via view rendering.
    controller_instance = @controller
    picks_by_tournament_and_user = controller_instance.instance_variable_get(:@picks_by_tournament_and_user)
    expect(picks_by_tournament_and_user).to be_a(Hash)

    tournament_hash = picks_by_tournament_and_user[tournament.id]
    expect(tournament_hash[creator.id]).to eq(creator_pick)
    expect(tournament_hash[member.id]).to eq(member_pick)
  end

  it "shows commissioner remove button for completed tournaments with warning copy" do
    winner = Golfer.create!(name: "Winner", external_id: "991")
    tournament.update!(starts_at: 3.days.ago, ends_at: 1.day.ago, champion_golfer: winner)
    Pick.create!(user: creator, pool_tournament: pool_tournament)

    get pool_path(pool)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Remove")
    expect(response.body).to include("tournament results and picks history will be removed")
  end

  it "does not show remove button to non-commissioners for completed tournaments" do
    winner = Golfer.create!(name: "Winner 2", external_id: "992")
    tournament.update!(starts_at: 3.days.ago, ends_at: 1.day.ago, champion_golfer: winner)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(member)

    get pool_path(pool)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("tournament results and picks history will be removed")
  end

  it "shows no picks submitted badge when tournament has no pool picks" do
    get pool_path(pool)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No picks submitted")
  end
end
