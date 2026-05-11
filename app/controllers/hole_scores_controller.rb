# frozen_string_literal: true

class HoleScoresController < ApplicationController
  before_action :set_event
  before_action :set_game
  before_action :require_event_member!
  before_action :require_game_not_submitted!
  before_action :set_and_authorize_gtp

  def update
    score = @gtp.hole_scores.find_or_initialize_by(hole_number: params[:hole_number].to_i)
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

  def require_game_not_submitted!
    return unless @game.submitted

    redirect_to event_game_path(@event, @game), alert: "This game has been submitted and is locked."
  end

  def set_and_authorize_gtp
    # Scope to this game first (prevents cross-game tampering)
    @gtp = GameTeamPlayer.joins(:game_team)
                         .where(game_teams: { game_id: @game.id })
                         .find(params[:id])

    # Commissioners may edit any player's scores
    return if @event.commissioner?(current_user)

    # Players may only edit their own row
    return if @gtp.user_id == current_user.id

    redirect_to event_game_path(@event, @game), alert: "You can only enter your own scores."
  end
end
