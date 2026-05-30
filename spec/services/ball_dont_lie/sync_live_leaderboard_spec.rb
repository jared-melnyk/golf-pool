# frozen_string_literal: true

require "rails_helper"

RSpec.describe BallDontLie::SyncLiveLeaderboard do
  let(:tournament) { Tournament.create!(name: "Schwab", starts_at: 1.day.ago, external_id: "28") }
  let(:client) { instance_double(BallDontLie::Client, fetch_all_tournament_results: api_rows) }
  let(:api_rows) { [] }

  before { allow(BallDontLie::Client).to receive(:new).and_return(client) }

  describe "#call" do
    context "with CUT and made-cut rows" do
      let(:api_rows) do
        [
          {
            "player" => { "id" => 100, "display_name" => "Made Cut" },
            "position" => "T18",
            "position_numeric" => 18,
            "earnings" => nil
          },
          {
            "player" => { "id" => 200, "display_name" => "Missed" },
            "position" => "CUT",
            "position_numeric" => nil,
            "earnings" => nil
          }
        ]
      end

      it "upserts golfers and results with position_display, without prize_money or champion" do
        result = described_class.new(tournament: tournament, client: client).call

        expect(result[:total]).to eq(2)
        mc = tournament.tournament_results.joins(:golfer).find_by(golfers: { external_id: "200" })
        expect(mc.position_display).to eq("CUT")
        expect(mc.position).to be_nil
        expect(mc.prize_money).to be_nil

        made = tournament.tournament_results.joins(:golfer).find_by(golfers: { external_id: "100" })
        expect(made.position_display).to eq("T18")
        expect(made.position).to eq(18)

        expect(tournament.reload.champion_golfer_id).to be_nil
        expect(tournament.leaderboard_synced_at).to be_within(5.seconds).of(Time.current)
      end
    end

    context "when tournament has no external_id" do
      let(:tournament) { Tournament.create!(name: "Local", starts_at: 1.day.from_now, external_id: nil) }

      it "raises ArgumentError" do
        expect { described_class.new(tournament: tournament, client: client).call }
          .to raise_error(ArgumentError, /external_id/)
      end
    end
  end
end
