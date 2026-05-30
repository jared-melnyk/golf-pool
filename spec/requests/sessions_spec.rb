# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  let(:user) { User.create!(name: "Pat", email: "pat@example.com", password: "password") }
  let(:session_key) { Rails.application.config.session_options[:key] }

  describe "POST /login" do
    it "sets remember cookies" do
      post login_path, params: { email: user.email, password: "password" }

      expect(response).to redirect_to(root_path)
      expect(cookies["remember_user_id"]).to be_present
      expect(cookies["remember_token"]).to be_present
    end
  end

  describe "remember cookie without session" do
    before do
      post login_path, params: { email: user.email, password: "password" }
      cookies.delete(session_key)
    end

    it "restores the signed-in user" do
      get pools_path

      expect(response).not_to redirect_to(login_path)
    end

    it "records a session start when restoring from remember cookies" do
      user.update_column(:last_login_at, 1.week.ago)
      previous = user.last_login_at

      get pools_path

      expect(user.reload.last_login_at).to be > previous
    end
  end

  describe "session start tracking" do
    before { user.update_column(:last_login_at, nil) }

    it "records last visit on the first authenticated request" do
      post login_path, params: { email: user.email, password: "password" }

      get pools_path

      expect(user.reload.last_login_at).to be_present
    end

    it "does not update last visit on subsequent requests in the same session" do
      post login_path, params: { email: user.email, password: "password" }
      get pools_path
      first_visit = user.reload.last_login_at

      travel 1.minute do
        get pools_path
      end

      expect(user.reload.last_login_at).to eq(first_visit)
    end
  end

  describe "DELETE /logout" do
    before { post login_path, params: { email: user.email, password: "password" } }

    it "clears session and remember cookies" do
      delete logout_path

      expect(response).to redirect_to(root_path)
      expect(cookies["remember_user_id"]).to be_blank
      expect(cookies["remember_token"]).to be_blank

      get pools_path
      expect(response).to redirect_to(login_path)
    end
  end
end
