# frozen_string_literal: true

require "rails_helper"

RSpec.describe BallDontLie::SyncRoundResults do
  let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.ago, ends_at: 1.day.from_now, external_id: "20") }
  let(:scottie) { Golfer.create!(name: "Scottie", external_id: "185") }
  let(:rory) { Golfer.create!(name: "Rory", external_id: "282") }

  let(:client) do
    instance_double(BallDontLie::Client,
                    fetch_all_player_round_results: round_results_payload,
                    fetch_all_player_scorecards: scorecards_payload)
  end
  let(:round_results_payload) { [] }
  let(:scorecards_payload) { [] }

  describe "#call" do
    context "when tournament has no external_id" do
      let(:tournament) { Tournament.create!(name: "Local", starts_at: 1.day.from_now, ends_at: 4.days.from_now, external_id: nil) }

      it "raises ArgumentError" do
        expect {
          described_class.new(tournament: tournament, player_ids: [ 1 ], client: client).call
        }.to raise_error(ArgumentError, /external_id/)
      end
    end

    context "with completed-round data only" do
      let(:round_results_payload) do
        [
          { "player" => { "id" => 185 }, "round_number" => 1, "par_relative_score" => -2 },
          { "player" => { "id" => 185 }, "round_number" => 2, "par_relative_score" => 1 }
        ]
      end

      it "creates TournamentRoundResult rows for each (player, round)" do
        scottie
        result = described_class.new(tournament: tournament, player_ids: [ 185 ], client: client).call

        rows = tournament.tournament_round_results.order(:round_number)
        expect(rows.size).to eq(2)
        expect(rows.map(&:round_number)).to eq([ 1, 2 ])
        expect(rows.map(&:score_to_par)).to eq([ -2, 1 ])
        expect(rows.map(&:last_hole_completed)).to eq([ 18, 18 ])
        expect(result[:created]).to eq(2)
        expect(result[:updated]).to eq(0)
      end

      it "updates live_results_synced_at" do
        scottie
        described_class.new(tournament: tournament, player_ids: [ 185 ], client: client).call
        expect(tournament.reload.live_results_synced_at).to be_within(5.seconds).of(Time.current)
      end

      it "does not fetch scorecards when the tournament is completed" do
        scottie
        winner = Golfer.create!(name: "Winner", external_id: "9991")
        tournament.update!(champion_golfer: winner)

        expect(client).not_to receive(:fetch_all_player_scorecards)
        described_class.new(tournament: tournament, player_ids: [ 185 ], client: client).call
      end
    end

    context "when the tournament is live and a round is in progress" do
      # Rory has an R2 row so current_round_number is 2; Scottie only has R1 from the API so R2
      # is filled from scorecards.
      let(:round_results_payload) do
        [
          { "player" => { "id" => 185 }, "round_number" => 1, "par_relative_score" => -2 },
          { "player" => { "id" => 282 }, "round_number" => 2, "par_relative_score" => 0 }
        ]
      end
      let(:scorecards_payload) do
        (1..9).map do |hole|
          { "player" => { "id" => 185 }, "round_number" => 2, "hole_number" => hole, "score" => 3, "par" => (hole == 1 ? 4 : 3) }
        end
      end

      it "fetches the current round's scorecards and persists the in-progress round" do
        scottie
        rory
        expect(client).to receive(:fetch_all_player_scorecards)
          .with(hash_including(tournament_ids: [ 20 ], player_ids: array_including(185, 282), round_number: 2))
          .and_return(scorecards_payload)

        described_class.new(tournament: tournament, player_ids: [ 185, 282 ], client: client).call

        live_row = tournament.tournament_round_results.find_by(golfer: scottie, round_number: 2)
        expect(live_row).to be_present
        expect(live_row.score_to_par).to be_a(Integer)
        expect(live_row.last_hole_completed).to eq(9)
      end
    end

    context "when called twice (idempotent upsert)" do
      let(:round_results_payload) do
        [ { "player" => { "id" => 185 }, "round_number" => 1, "par_relative_score" => -2 } ]
      end

      it "does not create duplicate rows" do
        scottie
        svc = described_class.new(tournament: tournament, player_ids: [ 185 ], client: client)
        svc.call
        expect { svc.call }.not_to change { TournamentRoundResult.count }
      end
    end

    context "when player_ids is omitted" do
      let(:pool) { Pool.create!(name: "P", creator: User.create!(email: "u@e.com", name: "U", password: "password")) }
      let(:pool_tournament) { PoolTournament.create!(pool: pool, tournament: tournament) }

      before do
        pick = Pick.create!(user: pool.creator, pool_tournament: pool_tournament)
        PickGolfer.create!(pick: pick, golfer: scottie, slot: 1)
        PickGolfer.create!(pick: pick, golfer: rory, slot: 2)
      end

      it "derives player_ids from picks for the tournament" do
        expect(client).to receive(:fetch_all_player_round_results)
          .with(hash_including(tournament_ids: [ 20 ], player_ids: a_collection_including(185, 282)))
          .and_return([])

        described_class.new(tournament: tournament, client: client).call
      end
    end
  end
end
