class RoundsController < ApplicationController
  include RoundSnapshotBuildable

  before_action :set_event
  before_action :require_event_member!
  before_action :require_commissioner!, only: [ :new, :create ]
  before_action :require_event_not_completed!, only: [ :new, :create ]

  def new
    @round = @event.rounds.new(played_on: Date.current)
    @search_query = params[:search_query].to_s.strip
    @course_search_results = []
    @selected_course = nil
    @tee_options = []

    return if @search_query.blank?

    unless golf_course_api_key_configured?
      flash.now[:alert] = GolfCourseApi::MissingApiKeyError::DEFAULT_MESSAGE
      return
    end

    @course_search_results = GolfCourseApi::CourseSearch.new(client: golf_course_client).call(@search_query)

    return if params[:course_id].blank?

    @selected_course = normalize_course_payload(golf_course_client.course(id: params[:course_id].to_i))
    @tee_options = tee_options_for(@selected_course)
    @round.name = default_round_name_for(@selected_course) if @round.name.blank?
  rescue GolfCourseApi::MissingApiKeyError => e
    flash.now[:alert] = e.message
  rescue StandardError => e
    flash.now[:alert] = "Could not load GolfCourseAPI data: #{e.message}"
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
      @search_query = ""
      @course_search_results = []
      @selected_course = nil
      @tee_options = []
      render :new, status: :unprocessable_entity
    end
  rescue GolfCourseApi::MissingApiKeyError => e
    @round = @event.rounds.new(round_params.except(:tee_selector))
    @search_query = ""
    @course_search_results = []
    @selected_course = nil
    @tee_options = []
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  rescue StandardError => e
    @round = @event.rounds.new(round_params.except(:tee_selector))
    @search_query = ""
    @course_search_results = []
    @selected_course = nil
    @tee_options = []
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
end
