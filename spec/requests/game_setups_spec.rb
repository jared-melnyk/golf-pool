# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Game setups", type: :request do
  let(:user) { User.create!(name: "Host", email: "host@test.com", password: "pw") }
  let(:game) { Game.create!(name: "Saturday", creator: user, status: "draft") }

  before do
    GameMembership.create!(game: game, user: user, role: "host")
    post login_path, params: { email: user.email, password: "pw" }
  end

  it "saves course and advances to format step" do
    snapshot = {
    golf_course_api_course_id: 1,
    course_name: "Test Course",
    club_name: "Test Club",
    tee_name: "Blue",
    tee_gender: "male",
    course_rating: 72.0,
    slope_rating: 128,
    par_total: 72,
    hole_pars: Array.new(18, 4),
    hole_handicaps: (1..18).to_a,
    course_snapshot: { "id" => 1 }
  }

    allow_any_instance_of(GameSetupsController).to receive(:build_snapshot).and_return(snapshot)

    patch game_setup_path(game), params: {
      step: "course",
      round: { played_on: Date.today, golf_course_api_course_id: 1, tee_selector: "male:0" }
    }

    expect(response).to redirect_to(game_setup_path(game, step: "format"))
    expect(game.reload.round).to be_present
    expect(game.round.course_name).to eq("Test Course")
  end
end
