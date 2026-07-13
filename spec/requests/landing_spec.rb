# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Landing", type: :request do
  describe "GET /" do
    context "when not signed in" do
      it "returns success and shows the landing page" do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("LongShot")
        expect(response.body).to include("Sign up")
        expect(response.body).to include("Sign in")
      end
    end

    context "when signed in" do
      let(:user) { User.create!(name: "Test", email: "test@example.com", password: "password") }

      before { post login_path, params: { email: user.email, password: "password" } }

      it "redirects to events" do
        get root_path
        expect(response).to redirect_to(events_path)
      end

      it "hides PGA Pools from the sidebar nav" do
        get events_path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("PGA Pools")
        expect(response.body).not_to include(">My pools<")
        expect(response.body).not_to include(">New pool<")
        expect(response.body).not_to include(">Rules<")
        expect(response.body).to include("On-Course games")
        expect(response.body).to include(">Events<")
      end
    end
  end
end
