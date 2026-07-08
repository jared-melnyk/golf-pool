# frozen_string_literal: true

# Shared configuration for the July 2026 Michigan golf trip:
# trip simulator, planning doc, and future event setup.
module TripConfig
  EVENT_NAME = "Michigan Golf Trip 2026"
  PASSWORD = "trip2026"
  TARGET_YARDAGE = 6100

  PLAYERS = [
    { key: :nitti, name: "Nitti", index: 4.8 },
    { key: :kevin, name: "Kevin Callaghan", index: 5.7 },
    { key: :joe, name: "Joe Mc", index: 12.0 },
    { key: :nick, name: "Nick Barajas", index: 13.6 },
    { key: :kyle, name: "Kyle Krivacek", index: 14.0 },
    { key: :ryan_flynn, name: "Ryan Flynn", index: 16.0 },
    { key: :jared, name: "Jared", index: 18.3 },
    { key: :chris, name: "Chris", index: 18.7 },
    { key: :greg, name: "Greg Lindemann", index: 19.0 },
    { key: :walker, name: "Walker Anglin", index: 25.0 },
    { key: :will, name: "Will Schmadeke", index: 36.0 },
    { key: :ryan_lannon, name: "Ryan Lannon", index: 36.0 }
  ].freeze

  VEGAS_SIT_OUT = %i[nitti nick walker will].freeze
  VEGAS_PLAYERS = (PLAYERS.map { |p| p[:key] } - VEGAS_SIT_OUT).freeze

  VEGAS_MATCHES = [
    {
      name: "Match 1",
      teams: [
        { name: "Team A", players: %i[kevin ryan_lannon] },
        { name: "Team B", players: %i[jared chris] }
      ]
    },
    {
      name: "Match 2",
      teams: [
        { name: "Team A", players: %i[joe greg] },
        { name: "Team B", players: %i[kyle ryan_flynn] }
      ]
    }
  ].freeze

  FOURSOME_GROUPINGS = {
    best_ball: [
      %i[nitti kyle jared will],
      %i[kevin joe chris walker],
      %i[nick ryan_flynn greg ryan_lannon]
    ],
    cha_cha_cha: [
      %i[kevin nick greg will],
      %i[nitti ryan_flynn chris ryan_lannon],
      %i[joe kyle jared walker]
    ],
    forty_score: [
      %i[nitti joe ryan_flynn ryan_lannon],
      %i[kevin kyle greg will],
      %i[nick jared chris walker]
    ]
  }.freeze

  # Tee data from GolfCourseAPI (July 2026) unless noted.
  COURSES = {
    arcadia_south: {
      golf_course_api_course_id: 26_721,
      club_name: "Arcadia Bluffs GC",
      course_name: "South",
      address: "14710 Loch Lomond Rd, Arcadia, MI 49613",
      tee_name: "White",
      tee_gender: "male",
      total_yards: 6491,
      course_rating: 70.6,
      slope_rating: 125,
      par_total: 72,
      hole_pars: [ 4, 4, 5, 4, 3, 5, 4, 3, 4, 4, 5, 3, 4, 5, 4, 3, 4, 4 ],
      hole_handicaps: [ 9, 15, 7, 1, 3, 13, 11, 17, 5, 10, 12, 14, 2, 16, 18, 4, 8, 6 ],
      api_sourced: true,
      tee_note: "White 6,491 yds — nearest to 6,100 yd target among Arcadia South tees"
    },
    wolf_river: {
      golf_course_api_course_id: 28_630,
      club_name: "Wolf River Golf Park",
      course_name: "Wolf River",
      address: "11685 Chippewa Hwy, Bear Lake, MI 49614",
      tee_name: "Bear Paw",
      tee_gender: "male",
      total_yards: 6114,
      course_rating: 69.4,
      slope_rating: 120,
      par_total: 72,
      hole_pars: [ 5, 4, 4, 4, 5, 4, 3, 4, 3, 3, 5, 4, 3, 4, 4, 5, 4, 4 ],
      hole_handicaps: [ 13, 17, 5, 1, 3, 7, 11, 15, 9, 16, 6, 12, 18, 2, 10, 4, 14, 8 ],
      api_sourced: true,
      api_legacy_name: "Bear Lake Highlands",
      tee_note: "Listed in GolfCourseAPI as Bear Lake Highlands (pre-2023 name). Bear Paw 6,114 yds."
    },
    champion_hill: {
      golf_course_api_course_id: 29_051,
      club_name: "Champion Hill GC",
      course_name: "Champion Hill",
      address: "10486 S M-37, Mesick, MI 49668",
      tee_name: "White",
      tee_gender: "male",
      total_yards: 6104,
      course_rating: 68.5,
      slope_rating: 120,
      par_total: 72,
      hole_pars: [ 4, 4, 4, 4, 5, 3, 5, 3, 4, 4, 3, 4, 3, 4, 4, 4, 5, 5 ],
      hole_handicaps: [ 11, 5, 9, 1, 17, 7, 15, 3, 13, 4, 16, 10, 14, 18, 6, 2, 12, 8 ],
      api_sourced: true,
      tee_note: "White 6,104 yds — nearest to 6,100 yds target"
    },
    pinecroft: {
      golf_course_api_course_id: 29_222,
      club_name: "Pinecroft GC",
      course_name: "Pinecroft",
      address: "Benzonia, MI",
      tee_name: "Blue",
      tee_gender: "male",
      total_yards: 6253,
      course_rating: 70.1,
      slope_rating: 126,
      par_total: 72,
      hole_pars: [ 4, 3, 5, 4, 4, 4, 3, 4, 5, 4, 4, 4, 4, 3, 4, 5, 3, 5 ],
      hole_handicaps: [ 16, 14, 4, 6, 18, 10, 8, 12, 2, 5, 1, 3, 15, 13, 7, 11, 17, 9 ],
      api_sourced: true,
      tee_note: "Blue 6,253 yds. Hole handicap ranking from course website (API values were missing)."
    }
  }.freeze

  ROUNDS = [
    {
      key: :vegas,
      label: "Round 1",
      date: Date.new(2026, 7, 16),
      tee_time: "8:00 AM",
      course_key: :arcadia_south,
      format: "vegas",
      format_label: "Vegas (2v2 wash)",
      players: 8,
      handicap_allowance: "100%"
    },
    {
      key: :best_ball,
      label: "Round 2",
      date: Date.new(2026, 7, 16),
      tee_time: "2:00 PM",
      course_key: :wolf_river,
      format: "best_ball",
      format_label: "Best Ball",
      players: 12,
      handicap_allowance: "85%"
    },
    {
      key: :cha_cha_cha,
      label: "Round 3",
      date: Date.new(2026, 7, 17),
      tee_time: "7:00 AM",
      course_key: :champion_hill,
      format: "cha_cha_cha",
      format_label: "Cha-Cha-Cha (1-2-3)",
      players: 12,
      handicap_allowance: "85%"
    },
    {
      key: :forty_score,
      label: "Round 4",
      date: Date.new(2026, 7, 17),
      tee_time: "2:00 PM",
      course_key: :pinecroft,
      format: "forty_score",
      format_label: "40 Score",
      players: 12,
      handicap_allowance: "100%"
    }
  ].freeze

  module_function

  def player(key)
    PLAYERS.find { |p| p[:key] == key.to_sym } or raise ArgumentError, "Unknown player: #{key}"
  end

  def player_index(key)
    PLAYERS.index { |p| p[:key] == key.to_sym } or raise ArgumentError, "Unknown player: #{key}"
  end

  def course(key)
    COURSES.fetch(key.to_sym)
  end

  def round(key)
    ROUNDS.find { |r| r[:key] == key.to_sym } or raise ArgumentError, "Unknown round: #{key}"
  end

  def round_attrs(course_key)
    c = course(course_key)
    hole_pars = c[:hole_pars] || default_pars(c[:par_total])
    hole_handicaps = c[:hole_handicaps] || (1..18).to_a

    {
      golf_course_api_course_id: c[:golf_course_api_course_id],
      course_name: c[:course_name],
      club_name: c[:club_name],
      tee_name: c[:tee_name],
      tee_gender: c[:tee_gender],
      course_rating: c[:course_rating],
      slope_rating: c[:slope_rating],
      par_total: c[:par_total],
      hole_pars: hole_pars,
      hole_handicaps: hole_handicaps
    }
  end

  def default_pars(par_total)
    Array.new(18, par_total / 18)
  end

  def vegas_sit_out_names
    VEGAS_SIT_OUT.map { |key| player(key)[:name] }
  end

  def planning_doc_path
    Rails.root.join("docs/trip/2026-07-michigan-golf-trip.md")
  end
end
