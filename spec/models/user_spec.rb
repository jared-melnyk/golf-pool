# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  let(:user) { User.create!(name: "Test", email: "test@example.com", password: "password") }

  describe "#generate_password_reset_token" do
    it "sets password_reset_token_digest and password_reset_sent_at and returns a raw token string" do
      raw_token = user.generate_password_reset_token

      expect(raw_token).to be_a(String)
      expect(raw_token).not_to be_empty
      user.reload
      expect(user.password_reset_token_digest).to be_present
      expect(user.password_reset_sent_at).to be_present
      expect(user.password_reset_token_valid?(raw_token)).to be true
    end
  end

  describe "#password_reset_token_valid?" do
    it "returns true for the token just generated" do
      raw_token = user.generate_password_reset_token
      expect(user.password_reset_token_valid?(raw_token)).to be true
    end

    it "returns false for a wrong token" do
      user.generate_password_reset_token
      expect(user.password_reset_token_valid?("wrong-token")).to be false
    end

    it "returns false when token is older than 1 hour" do
      raw_token = user.generate_password_reset_token
      user.update_columns(password_reset_sent_at: 2.hours.ago)
      expect(user.password_reset_token_valid?(raw_token)).to be false
    end
  end

  describe "#clear_password_reset!" do
    it "nils digest and sent_at" do
      user.generate_password_reset_token
      user.clear_password_reset!

      user.reload
      expect(user.password_reset_token_digest).to be_nil
      expect(user.password_reset_sent_at).to be_nil
    end
  end

  describe "#generate_remember_token" do
    it "stores a digest and returns a raw token" do
      raw_token = user.generate_remember_token

      expect(raw_token).to be_a(String)
      expect(raw_token).not_to be_empty
      user.reload
      expect(user.remember_token_digest).to be_present
      expect(user.remember_token_valid?(raw_token)).to be true
    end
  end

  describe "#remember_token_valid?" do
    it "returns false for a wrong token" do
      user.generate_remember_token
      expect(user.remember_token_valid?("wrong-token")).to be false
    end
  end

  describe "#clear_remember_token!" do
    it "nils remember_token_digest" do
      user.generate_remember_token
      user.clear_remember_token!

      user.reload
      expect(user.remember_token_digest).to be_nil
    end
  end
end
