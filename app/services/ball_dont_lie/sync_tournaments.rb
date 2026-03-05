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
        rec.total_prize_pool = parse_purse(t["purse"])
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
  end
end
