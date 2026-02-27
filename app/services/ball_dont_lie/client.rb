# frozen_string_literal: true

require "net/http"
require "json"

module BallDontLie
  class Client
    BASE_URL = "https://api.balldontlie.io/pga/v1"

    # ALL-STAR tier: 60 req/min. Sleep between requests to avoid 429.
    RATE_LIMIT_DELAY = (ENV["BALLDONTLIE_RATE_LIMIT_SEC"] || "1.1").to_f

    def initialize(api_key: nil)
      @api_key = api_key.presence || ENV["BALLDONTLIE_API_KEY"]
      raise ArgumentError, "BALLDONTLIE_API_KEY is required" if @api_key.blank?
    end

    def players(cursor: nil, per_page: 100)
      get "players", cursor: cursor, per_page: per_page
    end

    def tournaments(season: nil, cursor: nil, per_page: 100)
      get "tournaments", season: season, cursor: cursor, per_page: per_page
    end

    def tournament_results(tournament_ids: nil, cursor: nil, per_page: 100)
      params = { cursor: cursor, per_page: per_page }
      params["tournament_ids[]"] = Array(tournament_ids) if tournament_ids.present?
      get "tournament_results", **params
    end

    def tournament_field(tournament_id:, cursor: nil, per_page: 100)
      get "tournament_field", tournament_id: tournament_id, cursor: cursor, per_page: per_page
    end

    def fetch_all_tournament_field(tournament_id:)
      fetch_all("tournament_field", tournament_id: tournament_id) do |c|
        tournament_field(tournament_id: tournament_id, cursor: c, per_page: 100)
      end
    end

    def fetch_all_players
      fetch_all("players") { |c| players(cursor: c, per_page: 100) }
    end

    def fetch_all_tournaments(season:)
      fetch_all("tournaments", season: season) { |c| tournaments(season: season, cursor: c, per_page: 100) }
    end

    def fetch_all_tournament_results(tournament_ids:)
      fetch_all("tournament_results", tournament_ids: tournament_ids) do |c|
        tournament_results(tournament_ids: tournament_ids, cursor: c, per_page: 100)
      end
    end

    def futures(tournament_ids: nil, vendors: nil, cursor: nil, per_page: 100)
      params = { cursor: cursor, per_page: per_page }
      params["tournament_ids[]"] = Array(tournament_ids) if tournament_ids.present?
      params["vendors[]"] = Array(vendors) if vendors.present?
      get "futures", **params
    end

    private

    MAX_429_RETRIES = 3

    def get(path, **params)
      retry_count = params.delete(:retry_count) || 0
      params.compact!
      query = params.flat_map { |k, v| v.is_a?(Array) ? v.map { |x| [ k, x ] } : [ [ k, v ] ] }
      uri = URI("#{BASE_URL}/#{path}")
      uri.query = URI.encode_www_form(query) if query.any?
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = @api_key
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(req) }
      if res.code == "429" && retry_count < MAX_429_RETRIES
        wait = (res["Retry-After"]&.to_f || (RATE_LIMIT_DELAY * (5 * (retry_count + 1)))).clamp(5, 60)
        sleep wait
        return get(path, **params, retry_count: retry_count + 1)
      end
      if res.code == "401"
        hint = path.include?("tournament_field") ? " Tournament field requires BALLDONTLIE GOAT tier ($39.99/mo). Use \"Sync results\" on a completed tournament to add golfers (ALL-STAR)." : " Check BALLDONTLIE_API_KEY in .env."
        raise "API 401 Unauthorized.#{hint}"
      end
      raise "API error #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body)
    end

    def fetch_all(key, **opts)
      all = []
      cursor = nil
      loop do
        sleep RATE_LIMIT_DELAY
        resp = yield cursor
        data = resp["data"] || []
        all.concat(data)
        meta = resp["meta"] || {}
        cursor = meta["next_cursor"]
        break if cursor.blank? || data.size < (meta["per_page"] || 100)
      end
      all
    end
  end
end
