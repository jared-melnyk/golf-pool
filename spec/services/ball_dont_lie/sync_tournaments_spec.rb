# frozen_string_literal: true

require "rails_helper"

RSpec.describe BallDontLie::SyncTournaments do
  let(:client) { instance_double(BallDontLie::Client, fetch_all_tournaments: api_tournaments) }
  let(:api_tournaments) { [] }

  before do
    allow(BallDontLie::Client).to receive(:new).and_return(client)
  end

  describe "#call" do
    context "when API returns tournament with purse" do
      let(:api_tournaments) do
        [
          {
            "id" => 42,
            "name" => "The Masters",
            "start_date" => "2025-04-10",
            "end_date" => "Apr 10 - 13",
            "purse" => "$8,400,000"
          }
        ]
      end

      it "sets total_prize_pool from parsed purse" do
        result = described_class.new(season: 2025, client: client).call

        expect(result[:created]).to eq(1)
        tournament = Tournament.find_by(external_id: "42")
        expect(tournament).to be_present
        expect(tournament.total_prize_pool).to eq(BigDecimal("8400000"))
      end
    end

    context "when API returns end_date that parses to same as or before start_date" do
      let(:api_tournaments) do
        [
          {
            "id" => 99,
            "name" => "Bad End Date",
            "start_date" => "2025-04-10T12:00:00.000Z",
            "end_date" => "2025-04-10",
            "purse" => nil
          }
        ]
      end

      it "does not persist ends_at (we do not rely on unreliable API end_date)" do
        described_class.new(season: 2025, client: client).call
        tournament = Tournament.find_by(external_id: "99")
        expect(tournament).to be_present
        expect(tournament.ends_at).to be_nil
      end
    end

    context "when current-year API purse is missing or zero and previous year has a positive purse" do
      let(:client) { instance_double(BallDontLie::Client) }
      let(:current_year_rows) do
        [
          { "id" => 26, "name" => "PGA Championship", "start_date" => "2026-05-14", "end_date" => nil, "purse" => "$0" },
          { "id" => 31, "name" => "U.S. Open",        "start_date" => "2026-06-18", "end_date" => nil, "purse" => nil }
        ]
      end
      let(:prev_year_rows) do
        [
          { "id" => 7,  "name" => "PGA Championship", "purse" => "$19,000,000" },
          { "id" => 12, "name" => "U.S. Open",        "purse" => "$21,500,000" }
        ]
      end

      before do
        allow(client).to receive(:fetch_all_tournaments).with(season: 2026).and_return(current_year_rows)
        allow(client).to receive(:fetch_all_tournaments).with(season: 2025).and_return(prev_year_rows)
      end

      it "stores previous-year purse in fallback_prize_pool when current purse is missing or zero" do
        described_class.new(season: 2026, client: client).call

        pga = Tournament.find_by!(external_id: "26")
        uso = Tournament.find_by!(external_id: "31")

        expect(pga.total_prize_pool.to_i).to eq(0)
        expect(pga.fallback_prize_pool).to eq(BigDecimal("19000000"))
        expect(uso.total_prize_pool).to be_nil
        expect(uso.fallback_prize_pool).to eq(BigDecimal("21500000"))
      end

      it "fetches the previous-season list at most once per sync call (memoization)" do
        described_class.new(season: 2026, client: client).call

        expect(client).to have_received(:fetch_all_tournaments).with(season: 2025).once
      end
    end

    context "when previous-year fetch fails" do
      let(:client) { instance_double(BallDontLie::Client) }
      let(:current_year_rows) do
        [
          { "id" => 26, "name" => "PGA Championship", "start_date" => "2026-05-14", "end_date" => nil, "purse" => "$0" }
        ]
      end

      before do
        allow(client).to receive(:fetch_all_tournaments).with(season: 2026).and_return(current_year_rows)
        allow(client).to receive(:fetch_all_tournaments).with(season: 2025).and_raise(StandardError, "boom")
        allow(Rails.logger).to receive(:warn)
      end

      it "logs a warning and proceeds without setting a fallback" do
        expect { described_class.new(season: 2026, client: client).call }.not_to raise_error

        pga = Tournament.find_by!(external_id: "26")
        expect(pga.fallback_prize_pool).to be_nil
        expect(Rails.logger).to have_received(:warn).with(/SyncTournaments.*previous season/)
      end
    end

    context "when current API purse is positive" do
      let(:client) { instance_double(BallDontLie::Client) }
      let(:current_year_rows) do
        [
          { "id" => 17, "name" => "Valspar Championship", "start_date" => "2026-03-19", "end_date" => nil, "purse" => "$8,700,000" }
        ]
      end

      before do
        allow(client).to receive(:fetch_all_tournaments).with(season: 2026).and_return(current_year_rows)
      end

      it "does not call the previous-season endpoint at all" do
        described_class.new(season: 2026, client: client).call

        expect(client).not_to have_received(:fetch_all_tournaments).with(season: 2025)
      end
    end

    context "when an existing record has a fallback and the API returns no usable prev-year match" do
      let(:client) { instance_double(BallDontLie::Client) }
      let(:current_year_rows) do
        [
          { "id" => 26, "name" => "PGA Championship", "start_date" => "2026-05-14", "end_date" => nil, "purse" => "$0" }
        ]
      end

      before do
        Tournament.create!(external_id: "26", name: "PGA Championship", starts_at: Time.zone.parse("2026-05-14"), fallback_prize_pool: 19_000_000)
        allow(client).to receive(:fetch_all_tournaments).with(season: 2026).and_return(current_year_rows)
        allow(client).to receive(:fetch_all_tournaments).with(season: 2025).and_return([])
      end

      it "leaves the existing fallback_prize_pool untouched" do
        described_class.new(season: 2026, client: client).call

        expect(Tournament.find_by!(external_id: "26").fallback_prize_pool).to eq(BigDecimal("19000000"))
      end
    end
  end
end
