# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::EventMemberships", type: :request do
  let(:admin) { User.create!(name: "Admin", email: "admin@example.com", password: "password", admin: true) }
  let(:event) { Event.create!(name: "Michigan Trip", status: "active") }
  let(:golfer) { User.create!(name: "Walker", email: "walker@example.com", password: "password") }

  before { post login_path, params: { email: admin.email, password: "password" } }

  describe "POST /admin/events/:event_token/event_memberships" do
    it "adds the user as a player" do
      expect {
        post admin_event_event_memberships_path(event), params: { user_id: golfer.id }
      }.to change(EventMembership, :count).by(1)

      membership = EventMembership.find_by!(event: event, user: golfer)
      expect(membership.role).to eq("player")
      expect(response).to redirect_to(admin_event_path(event))
      follow_redirect!
      expect(flash[:notice]).to include("Walker")
    end

    it "forces player role even if a different role is submitted" do
      post admin_event_event_memberships_path(event), params: { user_id: golfer.id, role: "commissioner" }

      expect(EventMembership.find_by!(event: event, user: golfer).role).to eq("player")
    end

    it "alerts when user_id is missing" do
      expect {
        post admin_event_event_memberships_path(event), params: { user_id: "" }
      }.not_to change(EventMembership, :count)

      expect(response).to redirect_to(admin_event_path(event))
      expect(flash[:alert]).to be_present
    end

    it "alerts when the user is already a member" do
      EventMembership.create!(event: event, user: golfer, role: "player")

      expect {
        post admin_event_event_memberships_path(event), params: { user_id: golfer.id }
      }.not_to change(EventMembership, :count)

      expect(response).to redirect_to(admin_event_path(event))
      expect(flash[:alert]).to be_present
    end
  end

  describe "authorization" do
    let(:member) { User.create!(name: "Member", email: "member@example.com", password: "password", admin: false) }

    before { post login_path, params: { email: member.email, password: "password" } }

    it "redirects non-admin from create" do
      expect {
        post admin_event_event_memberships_path(event), params: { user_id: golfer.id }
      }.not_to change(EventMembership, :count)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Not authorized.")
    end
  end
end
