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

ActiveRecord::Schema[7.1].define(version: 2026_03_24_155101) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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
    t.index ["github_uid"], name: "index_users_on_github_uid", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

end
