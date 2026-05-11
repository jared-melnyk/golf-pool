# frozen_string_literal: true

class HoleScoresController < ApplicationController
  before_action :set_event
  before_action :set_game
  before_action :require_event_member!
  before_action :require_score_entry_permitted!

  def update
    gtp = GameTeamPlayer.joins(:game_team)
                        .where(game_teams: { game_id: @game.id })
                        .find(params[:id])
    score = gtp.hole_scores.find_or_initialize_by(hole_number: params[:hole_number].to_i)
    gross = params[:gross_score].to_s.strip

    if gross.blank?
      score.destroy if score.persisted?
    else
      score.gross_score = gross.to_i
      score.save!
    end

    redirect_to event_game_path(@event, @game), notice: "Score saved."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to event_game_path(@event, @game), alert: "Invalid score: #{e.message}"
  end

  private

  def set_event
    @event = Event.find_by!(token: params[:event_token])
  end

  def set_game
    @game = @event.games.find(params[:game_id])
  end

  def require_event_member!
    return if @event.member?(current_user)

    redirect_to event_path(@event), alert: "You must be a member of this event."
  end

  def require_score_entry_permitted!
    return if @event.commissioner?(current_user)
    return if @game.game_teams.joins(:game_team_players).where(game_team_players: { user_id: current_user.id }).exists?

    redirect_to event_game_path(@event, @game), alert: "You are not a participant in this game."
  end
end
