class CreatePageTotals < ActiveRecord::Migration[7.1]
  def change
    # Where the builder's daily totals stop: every view and click before it
    # is in them, every one from it on is read from its raw row.
    add_column :users, :rolled_up_to, :datetime

    # The day's views and visitors on a builder's page or a project's page,
    # in the builder's zone: what stays of a visitor's hash.
    create_table :page_days do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :page, null: false
      t.date :day, null: false
      t.integer :views, default: 0, null: false
      t.integer :visitors, default: 0, null: false
      t.index %i[user_id day page], unique: true
    end

    # The day's counts on a page by source, country, button, badge and embed.
    # The unique index also reads one kind's days.
    create_table :page_counts do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :page, null: false
      t.string :kind, null: false
      t.date :day, null: false
      t.string :value, null: false
      t.integer :count, default: 0, null: false
      t.index %i[user_id kind day page value], unique: true, name: "index_page_counts_once_a_day"
    end

    # By entry, not by page: a click counts for the project its entry is in
    # now, and goes with the entry.
    create_table :entry_click_days do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :entry, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.date :day, null: false
      t.integer :clicks, default: 0, null: false
      t.index %i[entry_id day], unique: true
      t.index %i[user_id day]
    end
  end
end
