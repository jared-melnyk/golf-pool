# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  describe "#password_reset" do
    let(:user) { User.create!(name: "Test", email: "test@example.com", password: "password") }
    let(:raw_token) { "abc123reset-token" }

    it "sends email to user with reset link containing the raw token" do
      mail = UserMailer.password_reset(user, raw_token)
      mail.deliver_now

      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to eq("Reset your password")
      expect(mail.body.encoded).to include(raw_token)
      expect(mail.body.encoded).to include(edit_password_reset_url(token: raw_token))
    end
  end
end
