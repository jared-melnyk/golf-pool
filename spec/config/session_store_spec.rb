# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Session store" do
  it "expires sessions after one year" do
    expect(Rails.application.config.session_options[:expire_after]).to eq(1.year)
  end

  it "uses the long_shot session key" do
    expect(Rails.application.config.session_options[:key]).to eq("_long_shot_session")
  end
end
