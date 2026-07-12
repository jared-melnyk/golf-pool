require "rails_helper"

RSpec.describe GameGuest, type: :model do
  let(:user) { User.create!(name: "Host", email: "host@example.com", password: "password123") }
  let(:event) { Event.create!(name: "Test Event", status: "active") }
  let(:round) do
    Round.create!(
      event: event, name: "Round", played_on: Date.today,
      golf_course_api_course_id: 1, course_name: "Course", tee_name: "White",
      tee_gender: "male", course_rating: 70.5, slope_rating: 120, par_total: 72,
      hole_pars: Array.new(18, 4), hole_handicaps: (1..18).to_a
    )
  end
  let(:game) { create_test_game!(event: event, round: round, game_type: "best_ball", creator: user) }

  it "requires name and handicap_index" do
    guest = GameGuest.new(game: game)
    expect(guest).not_to be_valid
    expect(guest.errors[:name]).to be_present
    expect(guest.errors[:handicap_index]).to be_present
  end

  it "creates with name and handicap_index" do
    guest = GameGuest.create!(game: game, name: "Jon", handicap_index: 14.2)
    expect(guest.name).to eq("Jon")
    expect(guest.handicap_index).to eq(14.2)
  end

  it "is destroyed with the game" do
    guest = GameGuest.create!(game: game, name: "Jon", handicap_index: 14.2)
    expect { game.destroy! }.to change(GameGuest, :count).by(-1)
    expect(GameGuest.find_by(id: guest.id)).to be_nil
  end
end
