# frozen_string_literal: true

module GolfCourseApi
  class MissingApiKeyError < StandardError
    DEFAULT_MESSAGE =
      "GolfCourseAPI key is missing. In the project root, copy .env.example to .env, set GOLF_COURSE_API_KEY " \
      "to your key from https://golfcourseapi.com (uncomment the line if needed), then restart the Rails server.".freeze

    def initialize(message = DEFAULT_MESSAGE)
      super(message)
    end
  end
end
