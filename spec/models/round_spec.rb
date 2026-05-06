# frozen_string_literal: true

require "rails_helper"

RSpec.describe Round, type: :model do
  let(:event) { Event.create!(name: "Bandon Trip") }

  it "is valid with required snapshot fields" do
    round = described_class.new(
      event: event,
      name: "Round 1",
      played_on: Date.current,
      golf_course_api_course_id: 99,
      course_name: "Pacific Dunes",
      tee_name: "Blue",
      tee_gender: "male",
      course_rating: BigDecimal("72.4"),
      slope_rating: 131,
      par_total: 72,
      hole_pars: Array.new(18, 4),
      hole_handicaps: (1..18).to_a
    )

    expect(round).to be_valid
  end

  it "requires 18 hole pars and handicaps" do
    round = described_class.new(
      event: event,
      name: "Round 1",
      played_on: Date.current,
      course_name: "Pacific Dunes",
      tee_name: "Blue",
      tee_gender: "male",
      course_rating: BigDecimal("72.4"),
      slope_rating: 131,
      par_total: 72,
      hole_pars: [ 4, 4 ],
      hole_handicaps: [ 1, 2 ]
    )

    expect(round).not_to be_valid
    expect(round.errors[:hole_pars]).to include("must have 18 values")
    expect(round.errors[:hole_handicaps]).to include("must have 18 values")
  end
end
