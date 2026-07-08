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

  describe "GET /admin/users/new" do
    it "renders the new user form" do
      get new_admin_user_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("New user")
    end
  end

  describe "POST /admin/users" do
    it "creates a user with normalized email and handicap" do
      expect {
        post admin_users_path, params: {
          user: {
            name: "Walker Anglin",
            email: "Walker@Example.com",
            password: "trip2026",
            password_confirmation: "trip2026",
            ghin_handicap_index: "25.0"
          }
        }
      }.to change(User, :count).by(1)

      user = User.last
      expect(user.email).to eq("walker@example.com")
      expect(user.ghin_handicap_index).to eq(25.0)
      expect(response).to redirect_to(admin_users_path)
    end

    it "rejects invalid users" do
      post admin_users_path, params: {
        user: { name: "", email: "bad@example.com", password: "trip2026", password_confirmation: "trip2026" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("can&#39;t be blank").or include("can't be blank")
    end
  end

  describe "GET /admin/users/:id/edit" do
    it "renders the edit form" do
      golfer = User.create!(name: "Golfer", email: "golfer@example.com", password: "password")

      get edit_admin_user_path(golfer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit user")
    end
  end

  describe "PATCH /admin/users/:id" do
    let(:golfer) { User.create!(name: "Golfer", email: "golfer@example.com", password: "password", ghin_handicap_index: nil) }

    it "updates name, email, and handicap" do
      patch admin_user_path(golfer), params: {
        user: {
          name: "Nick Barajas",
          email: "Nick.Barajas@Example.com",
          ghin_handicap_index: "13.6",
          password: "",
          password_confirmation: ""
        }
      }

      golfer.reload
      expect(golfer.name).to eq("Nick Barajas")
      expect(golfer.email).to eq("nick.barajas@example.com")
      expect(golfer.ghin_handicap_index).to eq(13.6)
      expect(golfer.authenticate("password")).to eq(golfer)
      expect(response).to redirect_to(admin_users_path)
    end

    it "updates password when provided" do
      patch admin_user_path(golfer), params: {
        user: {
          name: golfer.name,
          email: golfer.email,
          password: "newpassword",
          password_confirmation: "newpassword"
        }
      }

      expect(golfer.reload.authenticate("newpassword")).to eq(golfer)
    end

    it "rejects duplicate email" do
      User.create!(name: "Other", email: "taken@example.com", password: "password")

      patch admin_user_path(golfer), params: {
        user: { name: golfer.name, email: "taken@example.com", password: "", password_confirmation: "" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
