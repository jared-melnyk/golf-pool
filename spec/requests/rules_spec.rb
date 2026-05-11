# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rules", type: :request do
  describe "GET /rules" do
    context "when not signed in" do
      it "shows the rules page" do
        get rules_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("How to Win")
        expect(response.body).to include("top 45% of the field, plus ties")
      end
    end

    context "when signed in" do
      let(:user) { User.create!(name: "Test", email: "rules-user@example.com", password: "password") }

      before do
        post login_path, params: { email: user.email, password: "password" }
      end

      it "does not redirect to pools and shows the rules page" do
        get rules_path

        expect(response).to have_http_status(:ok)
        expect(response).not_to redirect_to(pools_path)
        expect(response.body).to include("How to Win")
      end
    end
  end
end
