# frozen_string_literal: true

module GolfCourseApi
  # GolfCourseAPI search matches whole words, not arbitrary prefixes (e.g. "bil" won't
  # match "Billy"). This wrapper adds supplemental API queries and client-side filtering
  # so typeahead feels like prefix/substring search.
  class CourseSearch
    TOKEN_SUFFIXES = %w[l ll ly y].freeze
    MIN_SUPPLEMENT_LENGTH = 2
    MAX_SUPPLEMENT_LENGTH = 4

    def initialize(client:)
      @client = client
    end

    def call(query)
      query = query.to_s.strip
      return [] if query.blank?

      direct = dedupe_by_id(search_api(query))
      return direct if direct.any?

      supplemental = dedupe_by_id(supplemental_courses(query))
      filter_by_query(supplemental, query)
    end

    private

    def search_api(term)
      return [] if term.blank?

      @client.search_courses(search_query: term).fetch("courses", [])
    end

    def supplemental_courses(query)
      words = query.split(/\s+/)

      if words.size >= 2
        supplemental_multi_word(words)
      elsif query.length >= MIN_SUPPLEMENT_LENGTH && query.length <= MAX_SUPPLEMENT_LENGTH
        supplemental_single_token(query)
      else
        []
      end
    end

    def supplemental_multi_word(words)
      extra = []
      stem = words[0..-2].join(" ")
      extra.concat(search_api(stem)) if stem.present?

      first_word = words.first
      extra.concat(search_api(first_word)) if first_word.length >= 3

      extra
    end

    def supplemental_single_token(word)
      extra = []
      TOKEN_SUFFIXES.each do |suffix|
        extra.concat(search_api(word + suffix))
      end
      extra
    end

    def dedupe_by_id(courses)
      courses.uniq { |course| course["id"] }
    end

    def filter_by_query(courses, query)
      tokens = query.downcase.split(/\s+/)

      courses.select do |course|
        haystack = course_label(course).downcase
        tokens.all? { |token| haystack.include?(token) }
      end
    end

    def course_label(course)
      "#{course['club_name']} #{course['course_name']}"
    end
  end
end
