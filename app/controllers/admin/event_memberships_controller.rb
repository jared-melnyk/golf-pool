# frozen_string_literal: true

module Admin
  class EventMembershipsController < ApplicationController
    before_action :require_admin
    before_action :set_event

    def create
      user = User.find_by(id: params[:user_id])
      if user.nil?
        redirect_to admin_event_path(@event), alert: "Select a user to add."
        return
      end

      if @event.member?(user)
        redirect_to admin_event_path(@event), alert: "#{user.name} is already on this event."
        return
      end

      @event.event_memberships.create!(user: user, role: "player")
      redirect_to admin_event_path(@event), notice: "#{user.name} added as a player."
    end

    private

    def set_event
      @event = Event.find_by!(token: params[:event_token])
    end
  end
end
