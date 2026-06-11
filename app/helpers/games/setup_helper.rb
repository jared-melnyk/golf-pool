# frozen_string_literal: true

module Games
  module SetupHelper
    def setup_previous_step(game, current_step)
      case current_step
      when "format"
        { label: "Course & tee", path: game_setup_path(game, step: "course") }
      when "invite"
        { label: "Game format", path: game_setup_path(game, step: "format") }
      end
    end

    def setup_step_number(current_step)
      { "course" => 1, "format" => 2, "invite" => 3 }.fetch(current_step, 1)
    end

    def course_search_location(course)
      city = course.dig("location", "city")
      state = course.dig("location", "state")
      return nil if city.blank? && state.blank?

      [ city, state ].compact.join(", ")
    end

    def event_round_label(round)
      [
        round.name,
        round.played_on.strftime("%b %-d, %Y"),
        round.club_name,
        round.course_name,
        "#{round.tee_gender.titleize} #{round.tee_name}"
      ].compact.join(" · ")
    end
  end
end
