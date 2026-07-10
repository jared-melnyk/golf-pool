# frozen_string_literal: true

require Rails.root.join("lib/golden_trip_helpers")

RSpec.configure do |config|
  config.include GoldenTripHelpers
end
