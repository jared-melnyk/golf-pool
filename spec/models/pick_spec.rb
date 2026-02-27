require "rails_helper"

RSpec.describe Pick, type: :model do
  describe "duplicate golfers validation" do
    let(:user) { User.create!(name: "User", email: "user@example.com", password: "password") }
    let(:tournament) { Tournament.create!(name: "Test Tournament") }
    let(:golfer1) { Golfer.create!(name: "Golfer 1", external_id: "1") }

    it "allows unique golfers across slots" do
      pick = Pick.new(user: user, tournament: tournament)
      pick.pick_golfers.build(golfer: golfer1, slot: 1)

      expect(pick).to be_valid
    end

    it "does not allow the same golfer to be selected twice" do
      pick = Pick.new(user: user, tournament: tournament)
      pick.pick_golfers.build(golfer: golfer1, slot: 1)
      pick.pick_golfers.build(golfer: golfer1, slot: 2)

      expect(pick).not_to be_valid
      expect(pick.errors.full_messages).to include("You can't pick the same golfer more than once for a tournament.")
    end
  end
end

