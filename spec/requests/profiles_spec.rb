# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Profile", type: :request do
  let(:user) { User.create!(email: "u@example.com", name: "User", password: "password") }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  it "updates GHIN handicap index" do
    patch profile_path, params: { user: { ghin_handicap_index: "12.4" } }

    expect(response).to redirect_to(edit_profile_path)
    expect(user.reload.ghin_handicap_index).to eq(BigDecimal("12.4"))
  end

  it "clears handicap when blank" do
    user.update!(ghin_handicap_index: 10)
    patch profile_path, params: { user: { ghin_handicap_index: "" } }

    expect(user.reload.ghin_handicap_index).to be_nil
  end
end
