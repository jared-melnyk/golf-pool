# frozen_string_literal: true

class HoleScoresController < ApplicationController
  include GameScorecardBuilder
  include GameAuthorizable

  helper Games::ScorecardHelper

  before_action :set_game
  before_action :require_game_access!
  before_action :require_game_not_completed!
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
      render_scorecard_update(alert: "Enter a gross score before counting this hole toward 40 Score.")
      return
    end

    want = ActiveModel::Type::Boolean.new.cast(params[:included_in_forty_score])
    score.included_in_forty_score = want
    score.save!

    render_scorecard_update
  rescue ActiveRecord::RecordInvalid => e
    render_scorecard_update(alert: e.record.errors.full_messages.to_sentence)
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

    render_scorecard_update
  rescue ActiveRecord::RecordInvalid => e
    render_scorecard_update(alert: "Invalid score: #{e.message}")
  end

  def render_scorecard_update(notice: nil, alert: nil)
    @event = @game.event
    @hole_number = params[:hole_number].to_i
    @game_team = @gtp.game_team
    @forty_pick_only = forty_pick_only?
    @scorecard = build_game_scorecard(@game.reload)
    @team_data = scorecard_team_for(@scorecard, @game_team)

    flash.now[:notice] = notice if notice
    flash.now[:alert] = alert if alert

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to game_path(@game), notice: notice, alert: alert }
    end
  end

  def forty_pick_only?
    @game.forty_score? && params[:forty_pick_only].present?
  end

  def set_and_authorize_gtp
    @gtp = GameTeamPlayer.joins(:game_team)
                         .where(game_teams: { game_id: @game.id })
                         .find(params[:id])

    return if @game.can_manage?(current_user)

    if forty_pick_only?
      return if teammate_of_authorized_gtp?
    else
      return if @gtp.user_id == current_user.id
    end

    redirect_to game_path(@game), alert: "You can only enter your own scores."
  end

  def teammate_of_authorized_gtp?
    GameTeamPlayer.joins(:game_team)
                  .where(game_teams: { id: @gtp.game_team_id, game_id: @game.id }, user_id: current_user.id)
                  .exists?
  end
end
