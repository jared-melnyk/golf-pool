# frozen_string_literal: true

class Events::StandingsController < ApplicationController
  def show
    @event = Event.find_by!(token: params[:event_token])
    unless @event.member?(current_user)
      redirect_to event_path(@event), alert: "Join this event to view standings."
      return
    end

    @rounds = @event.rounds.includes(:games).order(played_on: :asc, created_at: :asc)
    @round_standings = @rounds.map { |round| RoundStandings.new(round).call }
    @individual_standings = EventIndividualStandings.new(@event).call
  end
end
