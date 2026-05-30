# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  let(:admin) { User.create!(name: "Admin", email: "admin@example.com", password: "password", admin: true) }

  before { post login_path, params: { email: admin.email, password: "password" } }

  describe "GET /admin/users" do
    it "returns success for an admin" do
      get admin_users_path
      expect(response).to have_http_status(:ok)
    end

    it "lists users sorted by last login, most recent first" do
      recent = User.create!(name: "Recent", email: "recent@example.com", password: "password", last_login_at: 1.hour.ago)
      older = User.create!(name: "Older", email: "older@example.com", password: "password", last_login_at: 2.days.ago)
      never = User.create!(name: "Never", email: "never@example.com", password: "password")

      get admin_users_path

      expect(response.body.index(recent.name)).to be < response.body.index(older.name)
      expect(response.body.index(older.name)).to be < response.body.index(never.name)
    end

    it "shows name, email, and GHIN handicap index" do
      User.create!(
        name: "Golfer",
        email: "golfer@example.com",
        password: "password",
        ghin_handicap_index: 12.4,
        last_login_at: Time.current
      )

      get admin_users_path

      expect(response.body).to include("Golfer")
      expect(response.body).to include("golfer@example.com")
      expect(response.body).to include("12.4")
    end
  end

  describe "authorization" do
    let(:member) { User.create!(name: "Member", email: "member@example.com", password: "password", admin: false) }

    before { post login_path, params: { email: member.email, password: "password" } }

    it "redirects non-admin from users index" do
      get admin_users_path
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(flash[:alert]).to eq("Not authorized.")
    end
  end
end
