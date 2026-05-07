# frozen_string_literal: true

require "net/http"
require "json"

module GolfCourseApi
  class Client
    BASE_URL = "https://api.golfcourseapi.com/v1"

    def initialize(api_key: nil)
      @api_key = api_key.presence || ENV["GOLF_COURSE_API_KEY"].to_s.strip.presence
      raise MissingApiKeyError if @api_key.blank?
    end

    def search_courses(search_query:)
      get("search", search_query: search_query)
    end

    def course(id:)
      get("courses/#{id}")
    end

    private

    def get(path, **params)
      uri = URI("#{BASE_URL}/#{path}")
      uri.query = URI.encode_www_form(params.compact) if params.any?

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = @api_key
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }

      raise "Unauthorized. Check GOLF_COURSE_API_KEY." if response.code == "401"
      raise "GolfCourseAPI error #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
