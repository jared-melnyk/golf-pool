# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_27_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "golfers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "pick_golfers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "golfer_id", null: false
    t.bigint "pick_id", null: false
    t.integer "slot"
    t.datetime "updated_at", null: false
    t.index ["golfer_id"], name: "index_pick_golfers_on_golfer_id"
    t.index ["pick_id", "golfer_id"], name: "index_pick_golfers_on_pick_id_and_golfer_id", unique: true
    t.index ["pick_id", "slot"], name: "index_pick_golfers_on_pick_id_and_slot", unique: true
    t.index ["pick_id"], name: "index_pick_golfers_on_pick_id"
  end

  create_table "picks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "tournament_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["tournament_id"], name: "index_picks_on_tournament_id"
    t.index ["user_id", "tournament_id"], name: "index_picks_on_user_id_and_tournament_id", unique: true
    t.index ["user_id"], name: "index_picks_on_user_id"
  end

  create_table "pool_tournament_odds", force: :cascade do |t|
    t.integer "american_odds", null: false
    t.datetime "created_at", null: false
    t.bigint "golfer_id", null: false
    t.datetime "locked_at", null: false
    t.bigint "pool_tournament_id", null: false
    t.datetime "updated_at", null: false
    t.string "vendor"
    t.index ["golfer_id"], name: "index_pool_tournament_odds_on_golfer_id"
    t.index ["pool_tournament_id", "golfer_id"], name: "index_pool_tournament_odds_on_pt_and_golfer", unique: true
    t.index ["pool_tournament_id"], name: "index_pool_tournament_odds_on_pool_tournament_id"
  end

  create_table "pool_tournaments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "pool_id", null: false
    t.bigint "tournament_id", null: false
    t.datetime "updated_at", null: false
    t.index ["pool_id", "tournament_id"], name: "index_pool_tournaments_on_pool_id_and_tournament_id", unique: true
    t.index ["pool_id"], name: "index_pool_tournaments_on_pool_id"
    t.index ["tournament_id"], name: "index_pool_tournaments_on_tournament_id"
  end

  create_table "pool_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "pool_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["pool_id", "user_id"], name: "index_pool_users_on_pool_id_and_user_id", unique: true
    t.index ["pool_id"], name: "index_pool_users_on_pool_id"
    t.index ["user_id"], name: "index_pool_users_on_user_id"
  end

  create_table "pools", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "tournament_results", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "golfer_id", null: false
    t.integer "position"
    t.decimal "prize_money", precision: 12, scale: 2
    t.bigint "tournament_id", null: false
    t.datetime "updated_at", null: false
    t.index ["golfer_id"], name: "index_tournament_results_on_golfer_id"
    t.index ["tournament_id", "golfer_id"], name: "index_tournament_results_on_tournament_id_and_golfer_id", unique: true
    t.index ["tournament_id"], name: "index_tournament_results_on_tournament_id"
  end

  create_table "tournaments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ends_at"
    t.string "external_id"
    t.string "name"
    t.datetime "starts_at"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "pick_golfers", "golfers"
  add_foreign_key "pick_golfers", "picks"
  add_foreign_key "picks", "tournaments"
  add_foreign_key "picks", "users"
  add_foreign_key "pool_tournament_odds", "golfers"
  add_foreign_key "pool_tournament_odds", "pool_tournaments"
  add_foreign_key "pool_tournaments", "pools"
  add_foreign_key "pool_tournaments", "tournaments"
  add_foreign_key "pool_users", "pools"
  add_foreign_key "pool_users", "users"
  add_foreign_key "tournament_results", "golfers"
  add_foreign_key "tournament_results", "tournaments"
end
