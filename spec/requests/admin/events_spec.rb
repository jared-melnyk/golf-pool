# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Events", type: :request do
  let(:admin) { User.create!(name: "Admin", email: "admin@example.com", password: "password", admin: true) }

  before { post login_path, params: { email: admin.email, password: "password" } }

  describe "GET /admin/events" do
    it "returns success for an admin" do
      get admin_events_path
      expect(response).to have_http_status(:ok)
    end

    it "includes an Admin Events nav link" do
      get admin_events_path
      expect(response.body).to include(admin_events_path)
      expect(response.body).to include(">Events<")
    end

    it "lists events with name, status, and member count" do
      event = Event.create!(name: "Michigan Trip", status: "active")
      player = User.create!(name: "Player", email: "player@example.com", password: "password")
      EventMembership.create!(event: event, user: admin, role: "commissioner")
      EventMembership.create!(event: event, user: player, role: "player")

      get admin_events_path

      expect(response.body).to include("Michigan Trip")
      expect(response.body).to include("Active")
      expect(response.body).to include("2")
    end
  end

  describe "GET /admin/events/:token" do
    it "shows members and an add-member form" do
      event = Event.create!(name: "Michigan Trip", status: "draft")
      EventMembership.create!(event: event, user: admin, role: "commissioner")
      outsider = User.create!(name: "Outsider", email: "out@example.com", password: "password")

      get admin_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Michigan Trip")
      expect(response.body).to include(admin.name)
      expect(response.body).to include("Commissioner")
      expect(response.body).to include(outsider.name)
      expect(response.body).to include("Add")
    end
  end

  describe "authorization" do
    let(:member) { User.create!(name: "Member", email: "member@example.com", password: "password", admin: false) }

    before { post login_path, params: { email: member.email, password: "password" } }

    it "redirects non-admin from events index" do
      get admin_events_path
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(flash[:alert]).to eq("Not authorized.")
    end

    it "redirects non-admin from event show" do
      event = Event.create!(name: "Trip", status: "draft")
      get admin_event_path(event)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Not authorized.")
    end
  end
end
