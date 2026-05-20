# frozen_string_literal: true

class GameSetupsController < ApplicationController
  include GameAuthorizable
  include RoundSnapshotBuildable

  before_action :set_game
  before_action :require_game_manager!

  STEPS = %w[course format invite].freeze

  def show
    @step = params[:step].presence_in(STEPS) || next_step
    load_course_search_state if @step == "course"
  end

  def update
    case params[:step]
    when "course" then save_course!
    when "format" then save_format!
    else redirect_to game_setup_path(@game)
    end
  end

  private

  def next_step
    return "course" if @game.round.blank?
    return "format" if @game.game_type.blank?

    "invite"
  end

  def load_course_search_state
    @search_query = params[:search_query].to_s.strip
    @course_search_results = []
    @selected_course = nil
    @tee_options = []
    @round_played_on = params.dig(:round, :played_on).presence || Date.current

    return if @search_query.blank?

    unless golf_course_api_key_configured?
      flash.now[:alert] = GolfCourseApi::MissingApiKeyError::DEFAULT_MESSAGE
      return
    end

    @course_search_results = golf_course_client.search_courses(search_query: @search_query).fetch("courses", [])

    return if params[:course_id].blank?

    @selected_course = normalize_course_payload(golf_course_client.course(id: params[:course_id].to_i))
    @tee_options = tee_options_for(@selected_course)
  rescue GolfCourseApi::MissingApiKeyError => e
    flash.now[:alert] = e.message
  rescue StandardError => e
    flash.now[:alert] = "Could not load GolfCourseAPI data: #{e.message}"
  end

  def save_course!
    snapshot = build_snapshot(
      course_id: round_params.fetch(:golf_course_api_course_id).to_i,
      tee_selector: round_params.fetch(:tee_selector)
    )
    round = @game.round || Round.new(event: @game.event)
    round.assign_attributes(
      name: "Round at #{snapshot[:course_name]}",
      played_on: round_params.fetch(:played_on),
      golf_course_api_course_id: snapshot[:golf_course_api_course_id],
      course_name: snapshot[:course_name],
      club_name: snapshot[:club_name],
      tee_name: snapshot[:tee_name],
      tee_gender: snapshot[:tee_gender],
      course_rating: snapshot[:course_rating],
      slope_rating: snapshot[:slope_rating],
      par_total: snapshot[:par_total],
      hole_pars: snapshot[:hole_pars],
      hole_handicaps: snapshot[:hole_handicaps],
      course_snapshot: snapshot[:course_snapshot]
    )
    round.save!
    @game.update!(round: round, name: @game.suggested_name.presence || @game.name)
    redirect_to game_setup_path(@game, step: "format")
  rescue StandardError => e
    redirect_to game_setup_path(@game, step: "course"), alert: e.message
  end

  def save_format!
    @game.update!(game_type: params.require(:game).fetch(:game_type), status: "active", name: @game.suggested_name || @game.name)
    redirect_to game_setup_path(@game, step: "invite")
  end

  def round_params
    params.require(:round).permit(:played_on, :golf_course_api_course_id, :tee_selector)
  end
end
