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
        fetch_all_tournament_results: [],
        tournament_completed?: true
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
        fetch_all_tournament_results: [],
        tournament_completed?: true
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No picks were submitted for this tournament in this pool")
      expect(response.body).not_to include("Live scores are temporarily unavailable")
    end

    it "shows Cut Made Bonus column with — when no tournament results" do
      golfer = Golfer.create!(name: "Scottie", external_id: "185")
      Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
        PickGolfer.create!(pick: p, golfer: golfer, slot: 1)
      end
      PoolTournamentOdds.create!(pool_tournament: pool_tournament, golfer: golfer, american_odds: 500, vendor: "dk", locked_at: Time.current)

      client = instance_double(
        BallDontLie::Client,
        fetch_all_player_round_results: [],
        fetch_all_player_scorecards: [],
        fetch_all_tournament_results: [],
        tournament_completed?: true
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Cut Made Bonus")
      expect(response.body).to include("Scottie")
      # No TournamentResult => bonus cell shows "—"
      expect(response.body).to match(/Total.*Cut Made Bonus/m)
      expect(response.body).to include("—")
    end

    it "shows Cut Made Bonus amount when golfer made cut and has odds" do
      tournament.update!(total_prize_pool: 10_000_000)
      pool_tournament
      golfer = Golfer.create!(name: "Scottie", external_id: "185")
      winner = Golfer.create!(name: "Winner", external_id: "9991")
      tournament.update!(champion_golfer: winner)
      Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
        PickGolfer.create!(pick: p, golfer: golfer, slot: 1)
      end
      PoolTournamentOdds.create!(pool_tournament: pool_tournament, golfer: golfer, american_odds: 500, vendor: "dk", locked_at: Time.current)
      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 1, prize_money: 100_000)

      client = instance_double(
        BallDontLie::Client,
        fetch_all_player_round_results: [],
        fetch_all_player_scorecards: [],
        fetch_all_tournament_results: [],
        tournament_completed?: true
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      # 500 * 20 = 10,000 bonus
      expect(response.body).to include("10,000").or include("$10,000")
    end

    it "shows MC in Cut Made Bonus column when golfer missed the cut" do
      pool_tournament
      golfer = Golfer.create!(name: "Rory", external_id: "282")
      winner = Golfer.create!(name: "Winner", external_id: "9991")
      tournament.update!(champion_golfer: winner)
      Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
        PickGolfer.create!(pick: p, golfer: golfer, slot: 1)
      end
      PoolTournamentOdds.create!(pool_tournament: pool_tournament, golfer: golfer, american_odds: 400, vendor: "dk", locked_at: Time.current)
      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 80, prize_money: 0)

      client = instance_double(
        BallDontLie::Client,
        fetch_all_player_round_results: [],
        fetch_all_player_scorecards: [],
        fetch_all_tournament_results: [],
        tournament_completed?: true
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("MC")
    end

    it "shows dash instead of MC when tournament is in progress without cut posted" do
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
        fetch_all_tournament_results: [],
        tournament_completed?: true
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("MC")
      expect(response.body).to include("—")
      expect(response.body).not_to include("projected")
    end

    it "shows MC and cut bonus after cut without projected counted/dropped when curve is hidden" do
      tournament.update!(name: "Tour Championship", total_prize_pool: 10_000_000, payout_curve_source: "hidden")
      g_mc = Golfer.create!(name: "MC", external_id: "401")
      g_top = Golfer.create!(name: "Top", external_id: "402")
      g2 = Golfer.create!(name: "G2", external_id: "403")
      g3 = Golfer.create!(name: "G3", external_id: "404")

      Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
        PickGolfer.create!(pick: p, golfer: g_mc, slot: 1)
        PickGolfer.create!(pick: p, golfer: g_top, slot: 2)
        PickGolfer.create!(pick: p, golfer: g2, slot: 3)
        PickGolfer.create!(pick: p, golfer: g3, slot: 4)
      end

      [ g_mc, g_top, g2, g3 ].each do |g|
        PoolTournamentOdds.create!(pool_tournament: pool_tournament, golfer: g, american_odds: 500, vendor: "dk", locked_at: Time.current)
        TournamentRoundResult.create!(tournament: tournament, golfer: g, round_number: 1, score_to_par: 0, last_hole_completed: 18)
        TournamentRoundResult.create!(tournament: tournament, golfer: g, round_number: 2, score_to_par: 0, last_hole_completed: 18)
      end

      cut_marker = Golfer.create!(name: "CutMarker", external_id: "405")
      TournamentResult.create!(tournament: tournament, golfer: cut_marker, position_display: "CUT")
      TournamentResult.create!(tournament: tournament, golfer: g_mc, position_display: "CUT")
      TournamentResult.create!(tournament: tournament, golfer: g_top, position_display: "T2")
      TournamentResult.create!(tournament: tournament, golfer: g2, position_display: "T18")
      TournamentResult.create!(tournament: tournament, golfer: g3, position_display: "T42")

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("MC")
      expect(response.body).to include("$10,000")
      expect(response.body).not_to include("projected")
      expect(response.body).not_to include(">Counted</span>")
      expect(response.body).not_to include(">Dropped</span>")
      expect(response.body).to include("Total earnings and Counted/Dropped are shown after final prize money is posted")
    end

    it "shows projected prize, totals, and counted/dropped after cut when curve is available" do
      tournament.update!(
        name: "Live Projection Spec Open",
        total_prize_pool: 10_000_000,
        payout_curve_source: "static",
        payout_curve: PgaPayoutProfiles.curve_payload_for("standard_cut")
      )

      high_prize = Golfer.create!(name: "Hideki Matsuyama", external_id: "601")
      high_bonus = Golfer.create!(name: "Sahith Theegala", external_id: "602")
      g3 = Golfer.create!(name: "G3", external_id: "603")
      g4 = Golfer.create!(name: "G4", external_id: "604")

      Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
        PickGolfer.create!(pick: p, golfer: high_prize, slot: 1)
        PickGolfer.create!(pick: p, golfer: high_bonus, slot: 2)
        PickGolfer.create!(pick: p, golfer: g3, slot: 3)
        PickGolfer.create!(pick: p, golfer: g4, slot: 4)
      end

      [ [ high_prize, 1_000 ], [ high_bonus, 5_000 ], [ g3, 500 ], [ g4, 500 ] ].each do |golfer, odds|
        PoolTournamentOdds.create!(
          pool_tournament: pool_tournament, golfer: golfer, american_odds: odds,
          vendor: "dk", locked_at: Time.current
        )
        TournamentRoundResult.create!(tournament: tournament, golfer: golfer, round_number: 1, score_to_par: 0, last_hole_completed: 18)
        TournamentRoundResult.create!(tournament: tournament, golfer: golfer, round_number: 2, score_to_par: 0, last_hole_completed: 18)
      end

      cut_marker = Golfer.create!(name: "CutMarker", external_id: "605")
      TournamentResult.create!(tournament: tournament, golfer: cut_marker, position_display: "CUT")
      TournamentResult.create!(tournament: tournament, golfer: high_prize, position: 5, position_display: "T5")
      TournamentResult.create!(tournament: tournament, golfer: high_bonus, position: 12, position_display: "T12")
      TournamentResult.create!(tournament: tournament, golfer: g3, position: 30, position_display: "T30")
      TournamentResult.create!(tournament: tournament, golfer: g4, position: 50, position_display: "T50")

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("(projected)")
      expect(response.body).to include("Grey amounts are projected")
      body = response.body
      matsuyama_row = body[/Hideki Matsuyama.*?<\/tr>/m]
      theegala_row = body[/Sahith Theegala.*?<\/tr>/m]
      g4_row = body[/>\s*G4\s*<.*?<\/tr>/m]
      expect(matsuyama_row).to include("Counted (projected)")
      expect(matsuyama_row).not_to include("Dropped")
      expect(theegala_row).to include("Counted (projected)")
      expect(g4_row).to include("Dropped (projected)")
      expect(matsuyama_row).to include("text-gray-400")
      expect(matsuyama_row).to include("$")
    end

    it "shows Cut Made Bonus from live round data when no TournamentResult yet (round 3+ = made cut)" do
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
        fetch_all_tournament_results: [],
        tournament_completed?: true
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("10,000").or include("$10,000")
    end

    it "uses synthetic cut line for completed no-cut tournaments" do
      pool_tournament
      tournament.update!(total_prize_pool: 10_000_000)
      winner = Golfer.create!(name: "Winner", external_id: "winner-no-cut")
      tournament.update!(champion_golfer: winner)

      field_golfers = 10.times.map do |idx|
        g = Golfer.create!(name: "NC#{idx}", external_id: "no-cut-#{idx}")
        TournamentField.create!(tournament: tournament, golfer: g)
        TournamentResult.create!(tournament: tournament, golfer: g, position: idx + 1, prize_money: 1000)
        g
      end
      in_cut = field_golfers[4] # position 5
      out_cut = field_golfers[7] # position 8

      pick = Pick.create!(user: member, pool_tournament: pool_tournament)
      PickGolfer.create!(pick: pick, golfer: in_cut, slot: 1)
      PickGolfer.create!(pick: pick, golfer: out_cut, slot: 2)
      PoolTournamentOdds.create!(pool_tournament: pool_tournament, golfer: in_cut, american_odds: 500, vendor: "dk", locked_at: Time.current)
      PoolTournamentOdds.create!(pool_tournament: pool_tournament, golfer: out_cut, american_odds: 500, vendor: "dk", locked_at: Time.current)

      client = instance_double(
        BallDontLie::Client,
        fetch_all_player_round_results: [],
        fetch_all_player_scorecards: [],
        fetch_all_tournament_results: [],
        tournament_completed?: true
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("synthetic cut line")
      expect(response.body).to include("$10,000")
      expect(response.body).to include("MC")
    end

    it "counts golfers by prize plus bonus when the tournament is completed" do
      pool_tournament
      winner = Golfer.create!(name: "Winner", external_id: "9991")
      tournament.update!(champion_golfer: winner)
      high_prize = Golfer.create!(name: "Hideki Matsuyama", external_id: "601")
      high_bonus = Golfer.create!(name: "Sahith Theegala", external_id: "602")
      g3 = Golfer.create!(name: "G3", external_id: "603")
      g4 = Golfer.create!(name: "G4", external_id: "604")

      Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
        PickGolfer.create!(pick: p, golfer: high_prize, slot: 1)
        PickGolfer.create!(pick: p, golfer: high_bonus, slot: 2)
        PickGolfer.create!(pick: p, golfer: g3, slot: 3)
        PickGolfer.create!(pick: p, golfer: g4, slot: 4)
      end

      TournamentResult.create!(tournament: tournament, golfer: high_prize, position: 5, prize_money: 800_000)
      TournamentResult.create!(tournament: tournament, golfer: high_bonus, position: 12, prize_money: 300_000)
      TournamentResult.create!(tournament: tournament, golfer: g3, position: 20, prize_money: 150_000)
      TournamentResult.create!(tournament: tournament, golfer: g4, position: 40, prize_money: 50_000)

      [ [ high_prize, 1_000 ], [ high_bonus, 5_000 ], [ g3, 2_000 ], [ g4, 500 ] ].each do |golfer, odds|
        PoolTournamentOdds.create!(
          pool_tournament: pool_tournament,
          golfer: golfer,
          american_odds: odds,
          vendor: "dk",
          locked_at: Time.current
        )
      end

      client = instance_double(
        BallDontLie::Client,
        fetch_all_player_round_results: [],
        fetch_all_player_scorecards: [],
        fetch_all_tournament_results: [],
        tournament_completed?: true
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      body = response.body
      matsuyama_row = body[/Hideki Matsuyama.*?<\/tr>/m]
      theegala_row = body[/Sahith Theegala.*?<\/tr>/m]
      g4_row = body[/>\s*G4\s*<.*?<\/tr>/m]
      expect(matsuyama_row).to include("Counted")
      expect(matsuyama_row).not_to include("Dropped")
      expect(theegala_row).to include("Counted")
      expect(g4_row).to include("Dropped")
      expect(body).to include("$1,370,000")
    end

    it "marks top 3 golfer scores as counted and one as dropped" do
      pool_tournament
      winner = Golfer.create!(name: "Winner", external_id: "9991")
      tournament.update!(champion_golfer: winner)
      g1 = Golfer.create!(name: "G1", external_id: "301")
      g2 = Golfer.create!(name: "G2", external_id: "302")
      g3 = Golfer.create!(name: "G3", external_id: "303")
      g4 = Golfer.create!(name: "G4", external_id: "304")

      Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
        PickGolfer.create!(pick: p, golfer: g1, slot: 1)
        PickGolfer.create!(pick: p, golfer: g2, slot: 2)
        PickGolfer.create!(pick: p, golfer: g3, slot: 3)
        PickGolfer.create!(pick: p, golfer: g4, slot: 4)
      end

      TournamentResult.create!(tournament: tournament, golfer: g1, position: 1, prize_money: 100_000)
      TournamentResult.create!(tournament: tournament, golfer: g2, position: 2, prize_money: 80_000)
      TournamentResult.create!(tournament: tournament, golfer: g3, position: 3, prize_money: 50_000)
      TournamentResult.create!(tournament: tournament, golfer: g4, position: 4, prize_money: 10_000)

      client = instance_double(
        BallDontLie::Client,
        fetch_all_player_round_results: [],
        fetch_all_player_scorecards: [],
        fetch_all_tournament_results: [],
        tournament_completed?: true
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body.scan("Counted").size).to eq(3)
      expect(response.body.scan("Dropped").size).to eq(1)
      expect(response.body).to include("$230,000")
      expect(response.body).to include("line-through")
      expect(response.body).to include("Excluded golfers do not count toward the Total row")
    end

    it "shows marginal total-to-par on synthetic-cut banner when round data covers the field" do
      pool_tournament
      tournament.update!(total_prize_pool: 10_000_000, external_id: "555")
      winner = Golfer.create!(name: "Champ", external_id: "11000")
      tournament.update!(champion_golfer: winner)

      10.times do |i|
        g = Golfer.create!(name: "F#{i}", external_id: (11_001 + i).to_s)
        TournamentField.create!(tournament: tournament, golfer: g)
        TournamentResult.create!(tournament: tournament, golfer: g, position: i + 1, prize_money: 1000)
      end

      pick = Pick.create!(user: member, pool_tournament: pool_tournament)
      PickGolfer.create!(pick: pick, golfer: Golfer.find_by!(external_id: "11001"), slot: 1)
      PoolTournamentOdds.create!(pool_tournament: pool_tournament, golfer: Golfer.find_by!(external_id: "11001"), american_odds: 500, vendor: "dk", locked_at: Time.current)

      raw_round_results = (0..9).map do |i|
        pid = 11_001 + i
        val = i < 5 ? (i + 1) : 50
        { "player" => { "id" => pid }, "round_number" => 1, "par_relative_score" => val }
      end

      client = instance_double(
        BallDontLie::Client,
        fetch_all_player_round_results: raw_round_results,
        fetch_all_player_scorecards: [],
        fetch_all_tournament_results: [],
        tournament_completed?: true
      )
      allow(BallDontLie::Client).to receive(:new).and_return(client)

      get pool_pool_tournament_path(pool, pool_tournament)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("synthetic cut line")
      expect(response.body).to include("was <strong>+5</strong>")
    end

    context "with persisted TournamentRoundResult rows" do
      let!(:golfer) { Golfer.create!(name: "Scottie", external_id: "185") }
      let!(:pick) do
        Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
          PickGolfer.create!(pick: p, golfer: golfer, slot: 1)
        end
      end

      before do
        TournamentRoundResult.create!(tournament: tournament, golfer: golfer, round_number: 1, score_to_par: -3, last_hole_completed: 18)
        TournamentRoundResult.create!(tournament: tournament, golfer: golfer, round_number: 2, score_to_par: -1, last_hole_completed: 18)
        tournament.update_columns(live_results_synced_at: 5.seconds.ago, leaderboard_synced_at: 5.seconds.ago)
      end

      it "renders from DB without calling the API and without enqueuing a refresh" do
        expect(BallDontLie::Client).not_to receive(:new)
        expect {
          get pool_pool_tournament_path(pool, pool_tournament)
        }.not_to have_enqueued_job(RefreshLiveResultsJob)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Scottie")
        expect(response.body).to include("-3")
        expect(response.body).to include("-1")
      end

      it "enqueues RefreshLiveResultsJob when the snapshot is stale" do
        tournament.update_column(:live_results_synced_at, 2.minutes.ago)

        expect {
          get pool_pool_tournament_path(pool, pool_tournament)
        }.to have_enqueued_job(RefreshLiveResultsJob).with(tournament.id)
      end

      it "marks the API live round as Live even when only earlier rounds are persisted" do
        tournament.update_column(:live_round_number, 4)

        get pool_pool_tournament_path(pool, pool_tournament)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("R4 (Live)")
        expect(response.body).not_to include("R2 (Live)")
      end

      it "does not enqueue RefreshLiveResultsJob for a completed tournament" do
        winner = Golfer.create!(name: "Winner", external_id: "9991")
        tournament.update!(champion_golfer: winner)
        TournamentResult.create!(tournament: tournament, golfer: winner, position: 1, prize_money: 2_000_000)
        tournament.update_column(:live_results_synced_at, 2.minutes.ago)

        expect(BallDontLie::Client).not_to receive(:new)
        expect {
          get pool_pool_tournament_path(pool, pool_tournament)
        }.not_to have_enqueued_job(RefreshLiveResultsJob)
      end
    end

    context "with no persisted round data (cold start)" do
      let!(:golfer) { Golfer.create!(name: "Scottie", external_id: "185") }
      let!(:pick) do
        Pick.create!(user: member, pool_tournament: pool_tournament).tap do |p|
          PickGolfer.create!(pick: p, golfer: golfer, slot: 1)
        end
      end

      it "runs a synchronous SyncRoundResults and renders the resulting rows" do
        svc = instance_double(BallDontLie::SyncRoundResults)
        expect(BallDontLie::SyncRoundResults).to receive(:new).with(tournament: tournament, player_ids: include(185)).and_return(svc)
        expect(svc).to receive(:call) do
          TournamentRoundResult.create!(tournament: tournament, golfer: golfer, round_number: 1, score_to_par: -2, last_hole_completed: 18)
          tournament.update_column(:live_results_synced_at, Time.current)
          { created: 1, updated: 0, rounds_seen: 1 }
        end

        get pool_pool_tournament_path(pool, pool_tournament)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("-2")
      end
    end
  end
end
