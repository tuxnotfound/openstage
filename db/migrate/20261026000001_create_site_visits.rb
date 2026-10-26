class CreateSiteVisits < ActiveRecord::Migration[7.1]
  def change
    # Where a project's site visits come from (nil: nowhere), the script's
    # public token, when its first visit came, and whether its page shows them.
    change_table :github_repos, bulk: true do |t|
      t.string :site_source
      t.string :site_token
      t.datetime :site_first_visit_at
      t.boolean :site_visits_shown, default: true, null: false
      t.index :site_token, unique: true
    end

    # The day's totals, in the builder's zone: all that is kept for good.
    create_table :site_visit_days do |t|
      t.references :github_repo, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.date :day, null: false
      t.integer :visits, default: 0, null: false
      t.integer :visitors, default: 0, null: false
      t.timestamps
      t.index %i[github_repo_id day], unique: true
    end

    # Each visitor's hash and page views for the day, to count them once and
    # cap them; deleted once the day is over.
    create_table :site_visitors do |t|
      t.references :github_repo, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.date :day, null: false
      t.string :visitor_hash, null: false
      t.integer :hits, default: 1, null: false
      t.index %i[github_repo_id day visitor_hash], unique: true, name: "index_site_visitors_once_a_day"
      t.index :day
    end
  end
end
