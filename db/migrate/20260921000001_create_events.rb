# One narrow table for the handful of behaviours the gates are scored on.
# No IP, no user agent, no payload: a name, an optional detail, and a day.
class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :events do |t|
      t.references :user, null: true, foreign_key: true
      t.string :name, null: false
      t.string :detail, null: false, default: ""
      t.date :day, null: false
      t.datetime :created_at, null: false
    end

    # A signed-in user counts once per event per day. Anonymous rows have a
    # NULL user_id, which Postgres treats as distinct, so they are never deduped.
    add_index :events, [ :user_id, :name, :detail, :day ], unique: true, name: "index_events_once_per_user_per_day"
    add_index :events, [ :name, :day ]
  end
end
