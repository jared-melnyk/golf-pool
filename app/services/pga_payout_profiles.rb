# frozen_string_literal: true

# Static PGA payout ladders for live prize projection when empirical curves are unavailable.
class PgaPayoutProfiles
  CONFIG_PATH = Rails.root.join("config/payout_profiles.yml").freeze
  DEFAULT_PROFILE = "standard_cut"
  WINNER_20_PROFILE = "winner_20_cut"

  HIDDEN_NAME_PATTERNS = [
    /\btour championship\b/
  ].freeze

  NO_CUT_NAME_PATTERNS = [].freeze

  US_OPEN_NAME_PATTERNS = [
    /\bu\.s\. open\b/
  ].freeze

  OPEN_CHAMPIONSHIP_NAME_PATTERNS = [
    /\bthe open championship\b/
  ].freeze

  WINNER_20_NAME_PATTERNS = [
    /\bgenesis\b/,
    /\barnold palmer\b/,
    /\bmemorial tournament\b/
  ].freeze

  class << self
    def profile_id_for_name(name)
      key = normalize_name(name)
      return nil if key.blank?
      return nil if hidden_for_name?(key)

      return "us_open" if US_OPEN_NAME_PATTERNS.any? { |p| key.match?(p) }
      return "open_championship" if OPEN_CHAMPIONSHIP_NAME_PATTERNS.any? { |p| key.match?(p) }
      return WINNER_20_PROFILE if WINNER_20_NAME_PATTERNS.any? { |p| key.match?(p) }

      DEFAULT_PROFILE
    end

    def hidden_for_name?(name_or_key)
      key = name_or_key.to_s.downcase.strip
      return true if key.blank?

      HIDDEN_NAME_PATTERNS.any? { |p| key.match?(p) } ||
        NO_CUT_NAME_PATTERNS.any? { |p| key.match?(p) }
    end

    def shares_for(profile_id)
      case profile_id.to_s
      when WINNER_20_PROFILE
        winner_20_shares
      else
        raw = profiles_config.fetch(profile_id.to_s) { profiles_config.fetch(DEFAULT_PROFILE) }
        stringify_shares(raw)
      end
    end

    def curve_payload_for(profile_id)
      {
        "shares" => shares_for(profile_id),
        "metadata" => {
          "profile_id" => profile_id.to_s,
          "built_at" => Time.current.iso8601
        }
      }
    end

    private

    def normalize_name(name)
      name.to_s.downcase.strip
    end

    def profiles_config
      @profiles_config ||= YAML.load_file(CONFIG_PATH)
    end

    def stringify_shares(raw)
      raw.transform_keys(&:to_s).transform_values { |v| v.to_s }
    end

    def winner_20_shares
      base = shares_for(DEFAULT_PROFILE).transform_values(&:to_d)
      winner_share = BigDecimal("0.20")
      old_winner = base.fetch("1")
      remainder_target = BigDecimal("1") - winner_share
      old_remainder = BigDecimal("1") - old_winner
      scale = remainder_target / old_remainder

      scaled = base.transform_values { |share| (share * scale).to_s("F") }
      scaled["1"] = winner_share.to_s("F")
      scaled
    end
  end
end
