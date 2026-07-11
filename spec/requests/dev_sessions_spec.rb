# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dev trip sim login", type: :request do
  let!(:commissioner) do
    User.create!(
      name: "Trip Commissioner",
      email: "trip-commissioner@dryrun.test",
      password: "trip2026"
    )
  end

  it "signs in as commissioner and redirects to return_to" do
    get dev_trip_sim_login_path, params: { return_to: "/games/abc123" }

    expect(response).to redirect_to("/games/abc123")
    expect(session[:user_id]).to eq(commissioner.id)
  end

  it "rejects open redirects" do
    get dev_trip_sim_login_path, params: { return_to: "https://evil.example" }

    expect(response).to redirect_to(root_path)
    expect(session[:user_id]).to eq(commissioner.id)
  end

  it "404s when trip sim login is disabled" do
    allow(Rails.env).to receive(:local?).and_return(false)

    get dev_trip_sim_login_path, params: { return_to: "/games/abc123" }

    expect(response).to have_http_status(:not_found)
  end
end
