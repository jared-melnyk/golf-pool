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

ActiveRecord::Schema[8.1].define(version: 2026_03_04_205453) do
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
    t.bigint "pool_tournament_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["pool_tournament_id"], name: "index_picks_on_pool_tournament_id"
    t.index ["user_id", "pool_tournament_id"], name: "index_picks_on_user_id_and_pool_tournament_id", unique: true
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
    t.bigint "creator_id"
    t.string "name"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_pools_on_creator_id"
    t.index ["token"], name: "index_pools_on_token", unique: true
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tournament_fields", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "golfer_id", null: false
    t.bigint "tournament_id", null: false
    t.datetime "updated_at", null: false
    t.index ["golfer_id"], name: "index_tournament_fields_on_golfer_id"
    t.index ["tournament_id", "golfer_id"], name: "index_tournament_fields_on_tournament_and_golfer", unique: true
    t.index ["tournament_id"], name: "index_tournament_fields_on_tournament_id"
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
    t.datetime "results_synced_at"
    t.datetime "starts_at"
    t.decimal "total_prize_pool", precision: 12, scale: 2
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
  add_foreign_key "picks", "pool_tournaments"
  add_foreign_key "picks", "users"
  add_foreign_key "pool_tournament_odds", "golfers"
  add_foreign_key "pool_tournament_odds", "pool_tournaments"
  add_foreign_key "pool_tournaments", "pools"
  add_foreign_key "pool_tournaments", "tournaments"
  add_foreign_key "pool_users", "pools"
  add_foreign_key "pool_users", "users"
  add_foreign_key "pools", "users", column: "creator_id"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tournament_fields", "golfers"
  add_foreign_key "tournament_fields", "tournaments"
  add_foreign_key "tournament_results", "golfers"
  add_foreign_key "tournament_results", "tournaments"
end
