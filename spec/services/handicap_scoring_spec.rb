# frozen_string_literal: true

require "rails_helper"

RSpec.describe HandicapScoring do
  let(:host) do
    Class.new do
      include HandicapScoring
      public :net_for_hole
    end.new
  end

  it "returns nil when gross is nil" do
    expect(host.net_for_hole(nil, 2)).to be_nil
  end

  it "subtracts strokes when result stays above 1" do
    expect(host.net_for_hole(5, 2)).to eq(3)
  end

  it "floors at 1" do
    expect(host.net_for_hole(1, 2)).to eq(1)
    expect(host.net_for_hole(2, 2)).to eq(1)
  end
end
