# frozen_string_literal: true

module BallDontLie
  class SyncTournaments
    def initialize(season: Date.current.year, client: nil)
      @season = season
      @client = client || Client.new
    end

    def call
      api_tournaments = @client.fetch_all_tournaments(season: @season)
      created = updated = 0
      api_tournaments.each do |t|
        rec = Tournament.find_or_initialize_by(external_id: t["id"].to_s)
        rec.name = t["name"]
        rec.starts_at = parse_date(t["start_date"])
        rec.ends_at = parse_end_date(t["end_date"], rec.starts_at) # may be set to nil if API data is invalid

        parsed_purse = parse_purse(t["purse"])
        rec.total_prize_pool = parsed_purse

        if parsed_purse.nil? || !parsed_purse.positive?
          fallback = previous_season_purse_for(t["name"])
          rec.fallback_prize_pool = fallback if fallback&.positive?
        end

        if rec.new_record?
          rec.save!
          created += 1
        elsif rec.changed?
          rec.save!
          updated += 1
        end
      end
      { created: created, updated: updated, total: api_tournaments.size }
    end

    private

    def parse_date(str)
      return nil if str.blank?
      Time.zone.parse(str.to_s)
    end

    def parse_end_date(str, start_date)
      return nil if str.blank?
      parsed = Time.zone.parse(str.to_s) rescue nil
      return nil if parsed.blank? || start_date.blank?
      # API sometimes returns same as start_date or before; do not persist invalid end date
      return nil if parsed <= start_date
      parsed
    end

    def parse_purse(purse_str)
      return nil if purse_str.blank?
      cleaned = purse_str.to_s.gsub(/[$,]/, "").strip
      return nil if cleaned.blank?
      BigDecimal(cleaned)
    rescue ArgumentError, TypeError
      nil
    end

    # Returns the previous-season parsed purse for a given tournament name, or nil
    # when no positive match exists. The previous-season list is fetched lazily and
    # memoized so we hit the API at most once per sync run.
    def previous_season_purse_for(name)
      key = name.to_s.downcase.strip
      return nil if key.blank?

      previous_season_purse_by_name[key]
    end

    def previous_season_purse_by_name
      @previous_season_purse_by_name ||= load_previous_season_purse_by_name
    end

    def load_previous_season_purse_by_name
      rows = @client.fetch_all_tournaments(season: @season - 1)
      rows.each_with_object({}) do |t, h|
        key = t["name"].to_s.downcase.strip
        next if key.blank?
        purse = parse_purse(t["purse"])
        h[key] = purse if purse&.positive?
      end
    rescue => e
      Rails.logger.warn("[BallDontLie::SyncTournaments] failed to fetch previous season #{@season - 1} for fallback: #{e.class}: #{e.message}")
      {}
    end
  end
end
