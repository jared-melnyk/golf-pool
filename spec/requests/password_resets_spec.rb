# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Password resets", type: :request do
  describe "GET /forgot_password" do
    it "returns 200 and shows Forgot password and email field" do
      get forgot_password_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Forgot password?")
      expect(response.body).to include("email")
      expect(response.body).to include("Send reset link")
    end
  end

  describe "POST /forgot_password" do
    context "with valid email (user exists)" do
      let(:user) { User.create!(name: "Test", email: "test@example.com", password: "password") }

      it "sends email and redirects to login with success notice" do
        expect {
          perform_enqueued_jobs do
            post forgot_password_path, params: { email: user.email }
          end
        }.to change(ActionMailer::Base.deliveries, :size).by(1)

        expect(response).to redirect_to(login_path)
        expect(flash[:notice]).to eq("If an account exists for that email, we've sent a link to reset your password. Check your inbox and spam.")
      end
    end

    context "with unknown email" do
      it "redirects to login with same success notice and does not send email" do
        expect {
          post forgot_password_path, params: { email: "nobody@example.com" }
        }.not_to change(ActionMailer::Base.deliveries, :size)

        expect(response).to redirect_to(login_path)
        expect(flash[:notice]).to eq("If an account exists for that email, we've sent a link to reset your password. Check your inbox and spam.")
      end
    end
  end

  describe "GET /password_reset/:token" do
    context "with valid token" do
      let(:user) { User.create!(name: "Test", email: "test@example.com", password: "password") }
      let(:raw_token) { user.generate_password_reset_token }

      it "returns 200 and shows Set new password form" do
        get edit_password_reset_path(token: raw_token)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Set new password")
        expect(response.body).to include("password")
        expect(response.body).to include("Update password")
      end
    end

    context "with invalid or expired token" do
      it "redirects to login with invalid or expired message" do
        get edit_password_reset_path(token: "invalid-token")
        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to eq("That link is invalid or has expired.")
      end
    end
  end

  describe "PATCH /password_reset/:token" do
    context "with valid token and valid password" do
      let(:user) { User.create!(name: "Test", email: "test@example.com", password: "oldpass") }
      let(:raw_token) { user.generate_password_reset_token }

      it "updates password, clears token, and redirects to login with success" do
        patch password_reset_path(token: raw_token), params: { password: "newpass123", password_confirmation: "newpass123" }

        expect(response).to redirect_to(login_path)
        expect(flash[:notice]).to eq("Password updated. Sign in with your new password.")

        user.reload
        expect(user.password_reset_token_digest).to be_nil
        expect(user.password_reset_sent_at).to be_nil
        expect(user.authenticate("newpass123")).to eq(user)
      end
    end

    context "with invalid token" do
      it "redirects to login with error" do
        patch password_reset_path(token: "invalid-token"), params: { password: "newpass", password_confirmation: "newpass" }

        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to eq("That link is invalid or has expired.")
      end
    end

    context "with valid token but invalid password (confirmation mismatch)" do
      let(:user) { User.create!(name: "Test", email: "test@example.com", password: "oldpass") }
      let(:raw_token) { user.generate_password_reset_token }

      it "re-renders edit with 422 and errors" do
        patch password_reset_path(token: raw_token), params: { password: "newpass", password_confirmation: "mismatch" }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Set new password")
        expect(response.body).to include("Password confirmation")
        expect(response.body).to include("match")
      end
    end
  end
end
