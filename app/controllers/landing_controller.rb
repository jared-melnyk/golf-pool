# frozen_string_literal: true

class LandingController < ApplicationController
  skip_before_action :require_login, only: [ :index, :rules ]

  def index
    if current_user
      redirect_to events_path
    else
      render :index
    end
  end

  def rules
  end
end
