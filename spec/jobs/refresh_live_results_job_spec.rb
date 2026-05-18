require "rails_helper"

RSpec.describe RefreshLiveResultsJob, type: :job do
  let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.ago, ends_at: 1.day.from_now, external_id: "20") }

  it "invokes BallDontLie::SyncRoundResults for the tournament" do
    svc = instance_double(BallDontLie::SyncRoundResults, call: { created: 0, updated: 0, rounds_seen: 0 })
    expect(BallDontLie::SyncRoundResults).to receive(:new).with(tournament: tournament).and_return(svc)
    described_class.perform_now(tournament.id)
  end

  it "no-ops gracefully when the tournament does not exist" do
    expect(BallDontLie::SyncRoundResults).not_to receive(:new)
    expect { described_class.perform_now(0) }.not_to raise_error
  end

  it "no-ops when tournament has no external_id" do
    t = Tournament.create!(name: "Local", starts_at: 1.day.from_now, ends_at: 4.days.from_now, external_id: nil)
    expect(BallDontLie::SyncRoundResults).not_to receive(:new)
    described_class.perform_now(t.id)
  end

  it "logs and swallows service errors" do
    svc = instance_double(BallDontLie::SyncRoundResults)
    allow(BallDontLie::SyncRoundResults).to receive(:new).and_return(svc)
    allow(svc).to receive(:call).and_raise("boom")
    expect(Rails.logger).to receive(:error).with(/RefreshLiveResultsJob.*boom/)
    expect { described_class.perform_now(tournament.id) }.not_to raise_error
  end

  context "when the tournament has a champion but earnings are incomplete after the round sync" do
    let!(:winner) { Golfer.create!(name: "Winner", external_id: "9991") }

    before do
      tournament.update!(champion_golfer: winner)
      TournamentResult.create!(tournament: tournament, golfer: winner, position: 1, prize_money: 0)
    end

    it "runs SyncTournamentResults after the round sync" do
      round_svc = instance_double(BallDontLie::SyncRoundResults, call: {})
      final_svc = instance_double(BallDontLie::SyncTournamentResults, call: {})
      allow(BallDontLie::SyncRoundResults).to receive(:new).and_return(round_svc)
      expect(BallDontLie::SyncTournamentResults).to receive(:new).with(tournament: tournament).and_return(final_svc)

      described_class.perform_now(tournament.id)
    end
  end

  context "when the tournament likely finished and the API reports completion" do
    before do
      tournament.update!(starts_at: 4.days.ago)
    end

    it "runs SyncTournamentResults after the round sync" do
      round_svc = instance_double(BallDontLie::SyncRoundResults, call: {})
      final_svc = instance_double(BallDontLie::SyncTournamentResults, call: {})
      client = instance_double(BallDontLie::Client, tournament_completed?: true)
      allow(BallDontLie::SyncRoundResults).to receive(:new).and_return(round_svc)
      allow(BallDontLie::Client).to receive(:new).and_return(client)
      expect(BallDontLie::SyncTournamentResults).to receive(:new).with(tournament: tournament).and_return(final_svc)

      described_class.perform_now(tournament.id)
    end
  end

  context "when the tournament likely finished but the API is not complete yet" do
    before do
      tournament.update!(starts_at: 4.days.ago)
    end

    it "does not run SyncTournamentResults" do
      round_svc = instance_double(BallDontLie::SyncRoundResults, call: {})
      client = instance_double(BallDontLie::Client, tournament_completed?: false)
      allow(BallDontLie::SyncRoundResults).to receive(:new).and_return(round_svc)
      allow(BallDontLie::Client).to receive(:new).and_return(client)
      expect(BallDontLie::SyncTournamentResults).not_to receive(:new)

      described_class.perform_now(tournament.id)
    end
  end

  context "when the tournament is still early in the event" do
    before do
      tournament.update!(starts_at: 1.day.ago)
    end

    it "does not probe or run SyncTournamentResults" do
      round_svc = instance_double(BallDontLie::SyncRoundResults, call: {})
      allow(BallDontLie::SyncRoundResults).to receive(:new).and_return(round_svc)
      expect(BallDontLie::Client).not_to receive(:new)
      expect(BallDontLie::SyncTournamentResults).not_to receive(:new)

      described_class.perform_now(tournament.id)
    end
  end
end
