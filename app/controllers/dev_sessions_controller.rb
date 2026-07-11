# frozen_string_literal: true

# One-click sign-in for trip simulator dry-runs.
# Enabled in local envs, or when TRIP_SIM_LOGIN=1 (e.g. staging dry-run).
class DevSessionsController < ApplicationController
  skip_before_action :require_login, only: [ :create ]

  COMMISSIONER_EMAIL = "trip-commissioner@dryrun.test"

  def create
    unless trip_sim_login_allowed?
      head :not_found
      return
    end

    user = User.find_by(email: COMMISSIONER_EMAIL)
    unless user
      redirect_to login_path, alert: "Run `bundle exec rake trip:simulate` first."
      return
    end

    session[:user_id] = user.id
    remember_user(user)
    redirect_to safe_return_to
  end

  private

  def trip_sim_login_allowed?
    Rails.env.local? || ActiveModel::Type::Boolean.new.cast(ENV["TRIP_SIM_LOGIN"])
  end

  def safe_return_to
    path = params[:return_to].to_s
    return root_path unless path.start_with?("/") && !path.start_with?("//")

    path
  end
end
