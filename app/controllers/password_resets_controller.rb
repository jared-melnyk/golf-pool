# frozen_string_literal: true

class PasswordResetsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create, :edit, :update ]
  before_action :set_user_by_token, only: [ :edit, :update ]

  def new
  end

  def create
    email = params.permit(:email).fetch(:email, "").to_s.strip.downcase
    user = User.find_by(email: email)
    if user
      raw_token = user.generate_password_reset_token
      UserMailer.password_reset(user, raw_token).deliver_later
    end
    redirect_to login_path, notice: "If an account exists for that email, we've sent a link to reset your password. Check your inbox and spam."
  end

  def edit
    redirect_to login_path, alert: "That link is invalid or has expired." and return if @user.blank?
  end

  def update
    redirect_to login_path, alert: "That link is invalid or has expired." and return if @user.blank?
    if @user.update(update_params)
      @user.clear_password_reset!
      redirect_to login_path, notice: "Password updated. Sign in with your new password."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user_by_token
    @user = User.where.not(password_reset_token_digest: nil).find { |u| u.password_reset_token_valid?(params[:token]) }
  end

  def update_params
    params.permit(:password, :password_confirmation)
  end
end
