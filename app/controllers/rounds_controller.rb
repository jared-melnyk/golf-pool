class RoundsController < ApplicationController
  include RoundSnapshotBuildable
  include CourseSearchActions

  before_action :set_event
  before_action :require_event_member!
  before_action :require_commissioner!, only: [ :new, :create, :search_courses, :select_course ]
  before_action :require_event_not_completed!, only: [ :new, :create, :search_courses, :select_course ]

  def new
    @round = @event.rounds.new(played_on: Date.current)
    @search_query = ""
    @selected_course = nil
    @tee_options = []
    @selected_tee_selector = nil
    @default_round_name = nil
    @course_selection_error = nil
  end

  def select_course
    unless golf_course_api_key_configured?
      return render_course_selection_error(
        partial: "rounds/course_selection",
        message: GolfCourseApi::MissingApiKeyError::DEFAULT_MESSAGE
      )
    end

    load_selected_course(params[:course_id].to_i)
    @default_round_name = default_round_name_for(@selected_course)
    render partial: "rounds/course_selection",
           locals: {
             selected_course: @selected_course,
             tee_options: @tee_options,
             selected_tee_selector: @selected_tee_selector,
             default_round_name: @default_round_name,
             error_message: nil
           },
           layout: false
  rescue StandardError => e
    render_course_selection_error(partial: "rounds/course_selection", message: e.message)
  end

  def create
    snapshot = build_snapshot(
      course_id: round_params.fetch(:golf_course_api_course_id).to_i,
      tee_selector: round_params.fetch(:tee_selector)
    )

    @round = @event.rounds.new(
      name: round_params.fetch(:name),
      played_on: round_params.fetch(:played_on),
      golf_course_api_course_id: snapshot.fetch(:golf_course_api_course_id),
      course_name: snapshot.fetch(:course_name),
      club_name: snapshot[:club_name],
      tee_name: snapshot.fetch(:tee_name),
      tee_gender: snapshot.fetch(:tee_gender),
      course_rating: snapshot.fetch(:course_rating),
      slope_rating: snapshot.fetch(:slope_rating),
      par_total: snapshot.fetch(:par_total),
      hole_pars: snapshot.fetch(:hole_pars),
      hole_handicaps: snapshot.fetch(:hole_handicaps),
      course_snapshot: snapshot.fetch(:course_snapshot)
    )

    if @round.save
      redirect_to event_path(@event), notice: "Round created."
    else
      load_new_form_state_after_error
      render :new, status: :unprocessable_entity
    end
  rescue GolfCourseApi::MissingApiKeyError => e
    @round = @event.rounds.new(round_params.except(:tee_selector))
    load_new_form_state_after_error
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  rescue StandardError => e
    @round = @event.rounds.new(round_params.except(:tee_selector))
    load_new_form_state_after_error
    flash.now[:alert] = "Could not create round: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  private

  def set_event
    @event = Event.find_by!(token: params[:event_token])
  end

  def require_event_member!
    return if @event.member?(current_user)

    redirect_to event_path(@event), alert: "You must be a member of this event."
  end

  def require_commissioner!
    return if @event.commissioner?(current_user)

    redirect_to event_path(@event), alert: "Only commissioners can create rounds."
  end

  def round_params
    params.require(:round).permit(:name, :played_on, :golf_course_api_course_id, :tee_selector)
  end

  def require_event_not_completed!
    return unless @event.status == "completed"

    redirect_to event_path(@event), alert: "Cannot create rounds when an event is completed."
  end

  def load_new_form_state_after_error
    @search_query = ""
    @selected_course = nil
    @tee_options = []
    @selected_tee_selector = round_params[:tee_selector]
    @default_round_name = round_params[:name]
    @course_selection_error = nil
  end
end
