# frozen_string_literal: true

module CourseSearchActions
  extend ActiveSupport::Concern

  def search_courses
    @search_query = params[:search_query].to_s.strip
    @course_search_error = nil
    @course_search_results = fetch_course_search_results(@search_query)
    render partial: "shared/course_searches/results",
           locals: {
             course_search_results: @course_search_results,
             course_search_error: @course_search_error
           },
           layout: false
  end

  private

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

  def load_selected_course(course_id)
    @selected_course = normalize_course_payload(golf_course_client.course(id: course_id))
    @tee_options = tee_options_for(@selected_course)
  end

  def render_course_selection_error(partial:, message:, **locals)
    render partial: partial,
           locals: {
             error_message: message,
             selected_course: nil,
             tee_options: [],
             selected_tee_selector: nil,
             **locals
           },
           layout: false,
           status: :unprocessable_entity
  end
end
