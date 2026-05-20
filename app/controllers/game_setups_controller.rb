# frozen_string_literal: true

class GameSetupsController < ApplicationController
  include GameAuthorizable
  include RoundSnapshotBuildable

  before_action :set_game
  before_action :require_game_manager!

  STEPS = %w[course format invite].freeze

  def show
    @step = params[:step].presence_in(STEPS) || next_step
    load_course_step_state if @step == "course"
  end

  def search_courses
    @search_query = params[:search_query].to_s.strip
    @course_search_error = nil
    @course_search_results = fetch_course_search_results(@search_query)
    render partial: "game_setups/course_search_results",
           locals: {
             course_search_results: @course_search_results,
             course_search_error: @course_search_error
           },
           layout: false
  end

  def select_course
    unless golf_course_api_key_configured?
      return render_course_selection_error(GolfCourseApi::MissingApiKeyError::DEFAULT_MESSAGE)
    end

    select_course_by_id(params[:course_id].to_i)
    render partial: "game_setups/course_selection",
           locals: {
             selected_course: @selected_course,
             tee_options: @tee_options,
             selected_tee_selector: @selected_tee_selector,
             error_message: nil
           },
           layout: false
  rescue StandardError => e
    render_course_selection_error(e.message)
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

  def load_course_step_state
    @search_query = ""
    @course_search_results = []
    @selected_course = nil
    @tee_options = []
    @selected_tee_selector = params.dig(:round, :tee_selector)
    @round_played_on = round_played_on_from_params
    @course_selection_error = nil

    load_saved_round_course_state if @game.round.present?
  end

  def round_played_on_from_params
    raw = params.dig(:round, :played_on).presence
    raw ? Date.parse(raw.to_s) : (@game.round&.played_on || Date.current)
  rescue ArgumentError
    @game.round&.played_on || Date.current
  end

  def fetch_course_search_results(query)
    return [] if query.blank?

    unless golf_course_api_key_configured?
      @course_search_error = GolfCourseApi::MissingApiKeyError::DEFAULT_MESSAGE
      return []
    end

    GolfCourseApi::CourseSearch.new(client: golf_course_client).call(query)
  rescue GolfCourseApi::MissingApiKeyError => e
    @course_search_error = e.message
    []
  rescue StandardError => e
    @course_search_error = "Could not search courses: #{e.message}"
    []
  end

  def load_saved_round_course_state
    return unless golf_course_api_key_configured?

    select_course_by_id(@game.round.golf_course_api_course_id)
    @selected_tee_selector ||= tee_selector_for_round(@game.round, @selected_course)
    @search_query = "#{@game.round.club_name} · #{@game.round.course_name}"
  rescue GolfCourseApi::MissingApiKeyError => e
    @course_selection_error = e.message
  rescue StandardError => e
    @course_selection_error = "Could not load saved course: #{e.message}"
  end

  def select_course_by_id(course_id)
    @selected_course = normalize_course_payload(golf_course_client.course(id: course_id))
    @tee_options = tee_options_for(@selected_course)
    @selected_tee_selector ||= tee_selector_for_round(@game.round, @selected_course) if @game.round.present?
  end

  def render_course_selection_error(message)
    render partial: "game_setups/course_selection",
           locals: {
             error_message: message,
             selected_course: nil,
             tee_options: [],
             selected_tee_selector: nil
           },
           layout: false,
           status: :unprocessable_entity
  end

  def tee_selector_for_round(round, course_payload)
    return nil if round.blank? || course_payload.blank?

    index = male_tees_for(course_payload).find_index { |tee| tee["tee_name"] == round.tee_name }
    index ? "male:#{index}" : nil
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
