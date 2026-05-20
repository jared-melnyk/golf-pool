# frozen_string_literal: true

module RoundSnapshotBuildable
  extend ActiveSupport::Concern

  private

  def golf_course_api_key_configured?
    ENV["GOLF_COURSE_API_KEY"].to_s.strip.present?
  end

  def golf_course_client
    @golf_course_client ||= GolfCourseApi::Client.new
  end

  def tee_options_for(course_payload)
    male_tees_for(course_payload).each_with_index.map do |tee, index|
      yards_text = tee["total_yards"].present? ? " · #{helpers.number_with_delimiter(tee["total_yards"])} yds" : ""
      {
        value: "male:#{index}",
        label: "Male · #{tee["tee_name"]}#{yards_text} (Rating #{tee["course_rating"]}, Slope #{tee["slope_rating"]})"
      }
    end
  end

  def build_snapshot(course_id:, tee_selector:)
    course_payload = normalize_course_payload(golf_course_client.course(id: course_id))
    gender, index = tee_selector.to_s.split(":", 2)
    raise ArgumentError, "Only male tees are supported in v1" unless gender == "male"

    tee = male_tees_for(course_payload)[index.to_i]
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

  def normalize_course_payload(payload)
    return payload unless payload.is_a?(Hash)

    payload["course"].is_a?(Hash) ? payload["course"] : payload
  end

  def male_tees_for(course_payload)
    tees = course_payload.fetch("tees", {})
    return tees if tees.is_a?(Array)

    candidates = [ tees["male"], tees["Male"], tees["men"], tees["Men"] ]
    Array(candidates.find(&:present?))
  end

  def default_round_name_for(course_payload)
    course_name = course_payload["course_name"].presence || course_payload["club_name"].presence || "Round"
    "Round at #{course_name}"
  end
end
