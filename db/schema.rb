# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140915230754) do

  create_table "cycles", force: true do |t|
    t.integer  "session_id"
    t.integer  "total_edit_count"
    t.integer  "production_edit_count"
    t.integer  "test_edit_count"
    t.integer  "total_sloc_count"
    t.integer  "production_sloc_count"
    t.integer  "test_sloc_count"
    t.float    "statement_coverage"
    t.integer  "cyclomatic_complexity"
    t.boolean  "valid_tdd"
    t.integer  "cycle_position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "cycles", ["session_id"], name: "index_cycles_on_session_id"

  create_table "kata", force: true do |t|
    t.string   "kata_name"
    t.string   "cyberdojo_id"
    t.string   "language_framework"
    t.integer  "session_count"
    t.string   "path"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "lights", force: true do |t|
    t.integer  "phase_id"
    t.string   "light_color"
    t.integer  "git_tag"
    t.integer  "total_edited_line_count"
    t.integer  "production_edited_line_count"
    t.integer  "test_edited_line_count"
    t.integer  "total_test_method_count"
    t.integer  "total_test_run_fail_count"
    t.integer  "seconds_since_last_light"
    t.float    "statement_coverage"
    t.integer  "total_sloc_count"
    t.integer  "production_sloc_count"
    t.integer  "test_sloc_count"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "lights", ["phase_id"], name: "index_lights_on_phase_id"

  create_table "phases", force: true do |t|
    t.integer  "cycle_id"
    t.string   "tdd_color"
    t.integer  "seconds_in_phase"
    t.integer  "total_edit_count"
    t.integer  "production_edit_count"
    t.integer  "test_edit_count"
    t.integer  "total_sloc_count"
    t.integer  "production_sloc_count"
    t.integer  "test_sloc_count"
    t.integer  "total_line_change_count"
    t.integer  "production_line_change_count"
    t.integer  "test_line_change_count"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "phases", ["cycle_id"], name: "index_phases_on_cycle_id"

  create_table "sessions", force: true do |t|
    t.integer  "kata_id"
    t.string   "avatar"
    t.datetime "start_date"
    t.integer  "computed_time_secs"
    t.integer  "total_light_count"
    t.integer  "red_light_count"
    t.integer  "green_light_count"
    t.integer  "amber_light_count"
    t.integer  "max_consecutive_red_chain_length"
    t.integer  "total_sloc_count"
    t.integer  "production_sloc_count"
    t.integer  "test_sloc_count"
    t.integer  "total_edited_line_count"
    t.integer  "production_edited_line_count"
    t.integer  "test_edited_line_count"
    t.integer  "final_test_method_count"
    t.integer  "cumulative_test_run_count"
    t.integer  "cumulative_test_fail_count"
    t.integer  "final_cyclomatic_complexity"
    t.float    "final_branch_coverage"
    t.float    "final_statement_coverage"
    t.integer  "total_cycle_count"
    t.string   "final_light_color"
    t.float    "tdd_score"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "kata_name"
    t.string   "cyberdojo_id"
    t.string   "language_framework"
    t.string   "path"
  end

  add_index "sessions", ["kata_id"], name: "index_sessions_on_kata_id"

end
