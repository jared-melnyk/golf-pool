# frozen_string_literal: true

module Admin
  class EventsController < ApplicationController
    before_action :require_admin
    before_action :set_event, only: [ :show ]

    def index
      @events = Event.includes(:event_memberships).order(:name)
    end

    def show
      @memberships = @event.event_memberships.includes(:user).order("users.name")
      @addable_users = User.where.not(id: @event.user_ids).order(:name)
    end

    private

    def set_event
      @event = Event.find_by!(token: params[:token])
    end
  end
end
