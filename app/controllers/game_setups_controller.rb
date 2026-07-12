# frozen_string_literal: true

class GameSetupsController < ApplicationController
  include GameAuthorizable
  include RoundSnapshotBuildable
  include CourseSearchActions

  before_action :set_game
  before_action :require_game_manager!

  STEPS = %w[course format invite].freeze

  def show
    @step = params[:step].presence_in(STEPS) || next_step
    load_course_step_state if @step == "course"
  end

  def select_course
    unless golf_course_api_key_configured?
      return render_course_selection_error(
        partial: "shared/course_searches/selection",
        message: GolfCourseApi::MissingApiKeyError::DEFAULT_MESSAGE
      )
    end

    select_course_by_id(params[:course_id].to_i)
    render partial: "shared/course_searches/selection",
           locals: {
             selected_course: @selected_course,
             tee_options: @tee_options,
             selected_tee_selector: @selected_tee_selector,
             error_message: nil
           },
           layout: false
  rescue StandardError => e
    render_course_selection_error(partial: "shared/course_searches/selection", message: e.message)
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
    @event_rounds = @game.event&.rounds&.order(:played_on, :name) || Round.none
    @search_query = ""
    @course_search_results = []
    @selected_course = nil
    @tee_options = []
    @selected_tee_selector = params.dig(:round, :tee_selector)
    @round_played_on = round_played_on_from_params
    @course_selection_error = nil
    @selected_existing_round_id = selected_existing_round_id_for_form

    load_saved_round_course_state if @game.round.present? && @game.ad_hoc?
  end

  def round_played_on_from_params
    raw = params.dig(:round, :played_on).presence
    raw ? Date.parse(raw.to_s) : (@game.round&.played_on || Date.current)
  rescue ArgumentError
    @game.round&.played_on || Date.current
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
    load_selected_course(course_id)
    @selected_tee_selector ||= tee_selector_for_round(@game.round, @selected_course) if @game.round.present?
  end

  def save_course!
    if @game.event.present?
      save_existing_event_round!
    else
      save_new_round!
    end
  end

  def save_existing_event_round!
    round = @game.event.rounds.find(params.require(:existing_round_id))
    @game.update!(round: round, name: @game.suggested_name.presence || @game.name)
    redirect_to game_setup_path(@game, step: "format")
  rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing
    redirect_to game_setup_path(@game, step: "course"), alert: "Select a round from this event."
  end

  def save_new_round!
    snapshot = build_snapshot(
      course_id: round_params.fetch(:golf_course_api_course_id).to_i,
      tee_selector: round_params.fetch(:tee_selector)
    )
    round = @game.round || Round.new(event: @game.event)
    played_on = Date.parse(round_params.fetch(:played_on).to_s)
    round.assign_attributes(
      name: default_round_name_for(
        { "course_name" => snapshot[:course_name], "club_name" => snapshot[:club_name] },
        played_on: played_on
      ),
      played_on: played_on,
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

  def selected_existing_round_id_for_form
    return params[:existing_round_id] if params[:existing_round_id].present?
    return @game.round_id if @game.round.present? && @event_rounds.exists?(id: @game.round_id)

    nil
  end

  def save_format!
    @game.update!(game_type: params.require(:game).fetch(:game_type), status: "active", name: @game.suggested_name || @game.name)
    redirect_to game_setup_path(@game, step: "invite")
  end

  def round_params
    params.require(:round).permit(:played_on, :golf_course_api_course_id, :tee_selector)
  end
end
