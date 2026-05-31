# frozen_string_literal: true

require "rails_helper"

RSpec.describe BallDontLie::LiveRoundNumber do
  describe ".from_api" do
    let(:tournament_payload) do
      {
        "id" => 28,
        "rounds" => [
          { "round_number" => 1, "status" => "OFFICIAL" },
          { "round_number" => 2, "status" => "OFFICIAL" },
          { "round_number" => 3, "status" => "OFFICIAL" },
          { "round_number" => 4, "status" => "IN_PROGRESS" }
        ]
      }
    end

    it "returns the round marked IN_PROGRESS" do
      expect(described_class.from_api(tournament_payload: tournament_payload, fallback: 3)).to eq(4)
    end

    it "returns the round marked SUSPENDED" do
      payload = tournament_payload.deep_dup
      payload["rounds"][3]["status"] = "SUSPENDED"
      expect(described_class.from_api(tournament_payload: payload, fallback: 3)).to eq(4)
    end

    it "falls back when no round is live" do
      payload = {
        "rounds" => [
          { "round_number" => 1, "status" => "OFFICIAL" },
          { "round_number" => 2, "status" => "UPCOMING" }
        ]
      }
      expect(described_class.from_api(tournament_payload: payload, fallback: 1)).to eq(1)
    end

    it "falls back when rounds metadata is empty" do
      expect(described_class.from_api(tournament_payload: { "rounds" => [] }, fallback: 2)).to eq(2)
    end

    it "falls back when tournament payload is nil" do
      expect(described_class.from_api(tournament_payload: nil, fallback: 2)).to eq(2)
    end
  end

  describe ".tournament_payload_from" do
    it "prefers the first row that includes rounds metadata" do
      raw = [
        { "player" => { "id" => 1 }, "round_number" => 1 },
        {
          "player" => { "id" => 2 },
          "round_number" => 3,
          "tournament" => { "id" => 28, "rounds" => [ { "round_number" => 4, "status" => "IN_PROGRESS" } ] }
        }
      ]
      expect(described_class.tournament_payload_from(raw)).to eq(raw[1]["tournament"])
    end
  end
end
