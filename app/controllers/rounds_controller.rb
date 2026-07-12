class RoundsController < ApplicationController
  include RoundSnapshotBuildable
  include CourseSearchActions

  before_action :set_event
  before_action :set_round, only: [ :edit, :update, :destroy ]
  before_action :require_event_member!
  before_action :require_commissioner!, only: [ :new, :create, :edit, :update, :destroy, :search_courses, :select_course ]
  before_action :require_event_not_completed!, only: [ :new, :create, :edit, :update, :destroy, :search_courses, :select_course ]

  def new
    @round = @event.rounds.new(played_on: Date.current)
    load_form_state
  end

  def edit
    load_form_state
  end

  def select_course
    unless golf_course_api_key_configured?
      return render_course_selection_error(
        partial: "rounds/course_selection",
        message: GolfCourseApi::MissingApiKeyError::DEFAULT_MESSAGE
      )
    end

    load_selected_course(params[:course_id].to_i)
    @default_round_name = default_round_name_for(@selected_course, played_on: played_on_for_default_name)
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
    @round = @event.rounds.new
    save_round_from_params!
    redirect_to event_path(@event), notice: "Round created."
  rescue ActiveRecord::RecordInvalid
    load_form_state_after_error
    render :new, status: :unprocessable_entity
  rescue GolfCourseApi::MissingApiKeyError => e
    @round = @event.rounds.new(round_params.except(:tee_selector))
    load_form_state_after_error
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  rescue StandardError => e
    @round = @event.rounds.new(round_params.except(:tee_selector))
    load_form_state_after_error
    flash.now[:alert] = "Could not create round: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def update
    save_round_from_params!
    redirect_to event_path(@event), notice: "Round updated."
  rescue ActiveRecord::RecordInvalid
    load_form_state_after_error
    render :edit, status: :unprocessable_entity
  rescue GolfCourseApi::MissingApiKeyError => e
    load_form_state_after_error
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_entity
  rescue StandardError => e
    load_form_state_after_error
    flash.now[:alert] = "Could not update round: #{e.message}"
    render :edit, status: :unprocessable_entity
  end

  def destroy
    if @round.games.exists?
      redirect_to event_path(@event), alert: round_destroy_blocked_message
      return
    end

    @round.destroy!
    redirect_to event_path(@event), notice: "Round deleted."
  end

  private

  def set_event
    @event = Event.find_by!(token: params[:event_token])
  end

  def set_round
    @round = @event.rounds.find(params[:id])
  end

  def require_event_member!
    return if @event.member?(current_user)

    redirect_to event_path(@event), alert: "You must be a member of this event."
  end

  def require_commissioner!
    return if @event.commissioner?(current_user)

    redirect_to event_path(@event), alert: "Only commissioners can manage rounds."
  end

  def round_params
    params.require(:round).permit(:name, :played_on, :golf_course_api_course_id, :tee_selector)
  end

  def require_event_not_completed!
    return unless @event.status == "completed"

    redirect_to event_path(@event), alert: "Cannot manage rounds when an event is completed."
  end

  def save_round_from_params!
    snapshot = build_snapshot(
      course_id: round_params.fetch(:golf_course_api_course_id).to_i,
      tee_selector: round_params.fetch(:tee_selector)
    )
    assign_snapshot_to_round!(@round, snapshot, round_params)
    @round.save!
  end

  def load_form_state
    @search_query = ""
    @selected_course = nil
    @tee_options = []
    @selected_tee_selector = nil
    @default_round_name = nil
    @course_selection_error = nil

    return if @round.new_record?

    @search_query = [ @round.club_name, @round.course_name ].compact.join(" · ")
    @default_round_name = @round.name

    return if @round.course_snapshot.blank?

    @selected_course = normalize_course_payload(@round.course_snapshot)
    @tee_options = tee_options_for(@selected_course)
    @selected_tee_selector = tee_selector_for_round(@round, @selected_course)
  end

  def load_form_state_after_error
    @search_query = ""
    @selected_course = nil
    @tee_options = []
    @selected_tee_selector = round_params[:tee_selector]
    @default_round_name = round_params[:name]
    @course_selection_error = nil
  end

  def round_destroy_blocked_message
    game_names = @round.games.order(:name).limit(3).pluck(:name)
    suffix = game_names.any? ? " (#{game_names.join(', ')})" : ""
    count = @round.games.count
    "Cannot delete this round while #{count} #{'game'.pluralize(count)} use it#{suffix}."
  end

  def played_on_for_default_name
    raw = params[:played_on].presence || params.dig(:round, :played_on).presence
    raw ? Date.parse(raw.to_s) : Date.current
  rescue ArgumentError
    Date.current
  end
end
