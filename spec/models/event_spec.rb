# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event, type: :model do
  it "is valid with a name and default draft status" do
    event = Event.new(name: "Trip 2026")
    expect(event).to be_valid
    event.save!
    expect(event.status).to eq("draft")
    expect(event.token).to be_present
  end

  it "rejects invalid status" do
    event = Event.new(name: "X", status: "bogus")
    expect(event).not_to be_valid
  end
end
