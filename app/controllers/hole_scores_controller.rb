# frozen_string_literal: true

class HoleScoresController < ApplicationController
  before_action :set_event
  before_action :set_game
  before_action :require_event_member!
  before_action :require_game_not_submitted!
  before_action :set_and_authorize_gtp

  def update
    if forty_pick_only?
      update_forty_pick_only
    else
      update_gross_score
    end
  end

  private

  def update_forty_pick_only
    hole_num = params[:hole_number].to_i
    score = @gtp.hole_scores.find_by(hole_number: hole_num)

    unless score&.gross_score.present?
      redirect_to event_game_path(@event, @game), alert: "Enter a gross score before counting this hole toward 40 Score."
      return
    end

    want = ActiveModel::Type::Boolean.new.cast(params[:included_in_forty_score])
    score.included_in_forty_score = want
    score.save!

    redirect_to event_game_path(@event, @game), notice: "Pick updated."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to event_game_path(@event, @game), alert: e.record.errors.full_messages.to_sentence
  end

  def update_gross_score
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

  def forty_pick_only?
    @game.forty_score? && params[:forty_pick_only].present?
  end

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

    # Commissioners may edit any player's scores or 40 picks
    return if @event.commissioner?(current_user)

    if forty_pick_only?
      return if teammate_of_authorized_gtp?
    else
      return if @gtp.user_id == current_user.id
    end

    redirect_to event_game_path(@event, @game), alert: "You can only enter your own scores."
  end

  def teammate_of_authorized_gtp?
    GameTeamPlayer.joins(:game_team)
                  .where(game_teams: { id: @gtp.game_team_id, game_id: @game.id }, user_id: current_user.id)
                  .exists?
  end
end
