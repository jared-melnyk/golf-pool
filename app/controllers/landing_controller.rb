# frozen_string_literal: true

class LandingController < ApplicationController
  skip_before_action :require_login, only: [ :index ]

  def index
    if current_user
      redirect_to pools_path
    else
      render :index
    end
  end
end
