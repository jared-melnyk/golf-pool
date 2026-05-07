class RoundsController < ApplicationController
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

    @course_search_results = golf_course_client.search_courses(search_query: @search_query).fetch("courses", [])

    return if params[:course_id].blank?

    @selected_course = golf_course_client.course(id: params[:course_id].to_i)
    @tee_options = tee_options_for(@selected_course)
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

  def golf_course_api_key_configured?
    ENV["GOLF_COURSE_API_KEY"].to_s.strip.present?
  end

  def golf_course_client
    @golf_course_client ||= GolfCourseApi::Client.new
  end

  def tee_options_for(course_payload)
    tees = course_payload.fetch("tees", {})
    Array(tees["male"]).each_with_index.map do |tee, index|
      {
        value: "male:#{index}",
        label: "Male · #{tee["tee_name"]} (Rating #{tee["course_rating"]}, Slope #{tee["slope_rating"]})"
      }
    end
  end

  def build_snapshot(course_id:, tee_selector:)
    course_payload = golf_course_client.course(id: course_id)
    gender, index = tee_selector.to_s.split(":", 2)
    raise ArgumentError, "Only male tees are supported in v1" unless gender == "male"

    tee = Array(course_payload.dig("tees", gender))[index.to_i]
    raise ArgumentError, "Invalid tee selection" if tee.blank?
    raise ArgumentError, "Only 18-hole tees are supported in v1" unless tee["number_of_holes"].to_i == 18

    holes = Array(tee["holes"])
    raise ArgumentError, "Selected tee does not contain 18 holes" unless holes.size == 18

    {
      golf_course_api_course_id: course_id,
      course_name: course_payload["course_name"] || course_payload["club_name"],
      club_name: course_payload["club_name"],
      tee_name: tee["tee_name"],
      tee_gender: gender,
      course_rating: tee["course_rating"],
      slope_rating: tee["slope_rating"],
      par_total: tee["par_total"],
      hole_pars: holes.map { |hole| hole["par"].to_i },
      hole_handicaps: holes.map { |hole| hole["handicap"].to_i },
      course_snapshot: course_payload
    }
  end

  def require_event_not_completed!
    return unless @event.status == "completed"

    redirect_to event_path(@event), alert: "Cannot create rounds when an event is completed."
  end
end
