# frozen_string_literal: true

module Admin
  class GamesController < ApplicationController
    before_action :require_admin

    def index
      @games = Game.includes(:creator, :event, :round)
                   .left_joins(:round)
                   .order(Arel.sql("rounds.played_on DESC NULLS LAST"), created_at: :desc)
    end
  end
end
