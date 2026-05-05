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
      client = instance_double(
        BallDontLie::Client,
        fetch_all_player_round_results: [],
        fetch_all_tournament_results: []
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Live scores are temporarily unavailable").or include(pool.name)
    end

    it "shows a no-picks message instead of API-unavailable warning when nobody picked" do
      client = instance_double(
        BallDontLie::Client,
        fetch_all_player_round_results: [],
        fetch_all_tournament_results: []
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No picks were submitted for this tournament in this pool")
      expect(response.body).not_to include("Live scores are temporarily unavailable")
    end

    it "shows Bonus column with — when no tournament results" do
      golfer = Golfer.create!(name: "Scottie", external_id: "185")
      Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
        PickGolfer.create!(pick: p, golfer: golfer, slot: 1)
      end
      PoolTournamentOdds.create!(pool_tournament: pool_tournament, golfer: golfer, american_odds: 500, vendor: "dk", locked_at: Time.current)

      client = instance_double(
        BallDontLie::Client,
        fetch_all_player_round_results: [],
        fetch_all_player_scorecards: [],
        fetch_all_tournament_results: []
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bonus")
      expect(response.body).to include("Scottie")
      # No TournamentResult => bonus cell shows "—"
      expect(response.body).to match(/Total.*Bonus/m)
      expect(response.body).to include("—")
    end

    it "shows LongShot bonus amount when golfer made cut and has odds" do
      tournament.update!(total_prize_pool: 10_000_000)
      golfer = Golfer.create!(name: "Scottie", external_id: "185")
      Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
        PickGolfer.create!(pick: p, golfer: golfer, slot: 1)
      end
      PoolTournamentOdds.create!(pool_tournament: pool_tournament, golfer: golfer, american_odds: 500, vendor: "dk", locked_at: Time.current)
      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 1, prize_money: 100_000)

      client = instance_double(
        BallDontLie::Client,
        fetch_all_player_round_results: [],
        fetch_all_player_scorecards: [],
        fetch_all_tournament_results: []
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      # 500 * 20 = 10,000 bonus
      expect(response.body).to include("10,000").or include("$10,000")
    end

    it "shows MC in Bonus column when golfer missed the cut" do
      golfer = Golfer.create!(name: "Rory", external_id: "282")
      Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
        PickGolfer.create!(pick: p, golfer: golfer, slot: 1)
      end
      PoolTournamentOdds.create!(pool_tournament: pool_tournament, golfer: golfer, american_odds: 400, vendor: "dk", locked_at: Time.current)
      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 80, prize_money: 0)

      client = instance_double(
        BallDontLie::Client,
        fetch_all_player_round_results: [],
        fetch_all_player_scorecards: [],
        fetch_all_tournament_results: []
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("MC")
    end

    it "shows LongShot bonus from live round data when no TournamentResult yet (round 3+ = made cut)" do
      tournament.update!(total_prize_pool: 10_000_000)
      golfer = Golfer.create!(name: "Scottie", external_id: "185")
      Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
        PickGolfer.create!(pick: p, golfer: golfer, slot: 1)
      end
      PoolTournamentOdds.create!(pool_tournament: pool_tournament, golfer: golfer, american_odds: 500, vendor: "dk", locked_at: Time.current)
      # No TournamentResult — tournament still in progress

      # API returns round 3 data so we infer made cut and show bonus
      raw_round_results = [
        { "player" => { "id" => 185 }, "round_number" => 3, "par_relative_score" => -1 }
      ]
      client = instance_double(
        BallDontLie::Client,
        fetch_all_player_round_results: raw_round_results,
        fetch_all_player_scorecards: [],
        fetch_all_tournament_results: []
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("10,000").or include("$10,000")
    end
  end
end
