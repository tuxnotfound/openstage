class CreateSiteVisitCounts < ActiveRecord::Migration[7.1]
  def change
    # The day's counts on a project's website by page, source, ref tag and
    # country, in the builder's zone: totals only, kept for good like
    # site_visit_days. The unique index also reads one project's days of one
    # kind.
    create_table :site_visit_counts do |t|
      t.references :github_repo, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.date :day, null: false
      t.string :value, null: false
      t.integer :count, default: 0, null: false
      t.index %i[github_repo_id kind day value], unique: true, name: "index_site_visit_counts_once_a_day"
    end
  end
end
