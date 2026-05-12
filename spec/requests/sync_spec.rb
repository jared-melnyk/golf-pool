# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sync", type: :request do
  let(:admin) { User.create!(name: "Admin", email: "admin@example.com", password: "password", admin: true) }
  let(:member) { User.create!(name: "Member", email: "member@example.com", password: "password", admin: false) }
  let(:tournament) { Tournament.create!(name: "T", starts_at: 1.day.from_now, ends_at: 2.days.from_now, external_id: "42") }

  describe "POST /sync/field" do
    it "rejects signed-in non-admins" do
      post login_path, params: { email: member.email, password: "password" }
      post sync_field_path, params: { tournament_id: tournament.id }
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(flash[:alert]).to eq("Not authorized.")
    end

    it "allows signed-in admins" do
      post login_path, params: { email: admin.email, password: "password" }
      syncer = instance_double(BallDontLie::SyncTournamentField, call: { total: 1 })
      allow(BallDontLie::SyncTournamentField).to receive(:new).and_return(syncer)

      post sync_field_path, params: { tournament_id: tournament.id }

      expect(response).to redirect_to(tournament_path(tournament))
    end
  end

  describe "POST /sync/tournament_results/:tournament_id" do
    it "rejects signed-in non-admins" do
      post login_path, params: { email: member.email, password: "password" }
      post sync_tournament_results_path(tournament)
      expect(response).to redirect_to(root_path)
    end

    it "allows signed-in admins" do
      post login_path, params: { email: admin.email, password: "password" }
      syncer = instance_double(BallDontLie::SyncTournamentResults, call: { created: 0, updated: 0, total: 0 })
      allow(BallDontLie::SyncTournamentResults).to receive(:new).and_return(syncer)

      post sync_tournament_results_path(tournament)

      expect(response).to redirect_to(tournament_path(tournament))
    end
  end
end
