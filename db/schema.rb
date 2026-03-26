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

ActiveRecord::Schema[7.1].define(version: 2026_03_26_172743) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "entries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "entry_type", null: false
    t.string "source", null: false
    t.string "title", null: false
    t.text "body"
    t.string "url"
    t.datetime "occurred_at", null: false
    t.boolean "hidden", default: false, null: false
    t.string "external_id"
    t.string "repo_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "external_id"], name: "index_entries_on_user_id_and_external_id", unique: true
    t.index ["user_id", "occurred_at"], name: "index_entries_on_user_id_and_occurred_at"
    t.index ["user_id"], name: "index_entries_on_user_id"
  end

  create_table "github_repos", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "github_repo_id", null: false
    t.string "name", null: false
    t.string "full_name", null: false
    t.text "description"
    t.string "url"
    t.boolean "included", default: true, null: false
    t.string "default_branch"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "github_repo_id"], name: "index_github_repos_on_user_id_and_github_repo_id", unique: true
    t.index ["user_id"], name: "index_github_repos_on_user_id"
  end

  create_table "sync_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "source", null: false
    t.string "status", null: false
    t.integer "entries_added", default: 0, null: false
    t.text "error_message"
    t.datetime "ran_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sync_logs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "github_uid"
    t.string "github_username"
    t.string "github_access_token"
    t.string "username"
    t.string "display_name"
    t.text "bio"
    t.string "avatar_url"
    t.string "website_url"
    t.date "building_since"
    t.datetime "username_changed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["github_uid"], name: "index_users_on_github_uid", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "entries", "users"
  add_foreign_key "github_repos", "users"
  add_foreign_key "sync_logs", "users"
end
