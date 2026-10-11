# A builder's card for one week: what goes on it, each day's headline in their
# own words, and the post that goes out with it. Everything is on by default,
# so the card stores only what the builder turned off.
class CreateWeekCards < ActiveRecord::Migration[7.1]
  def change
    create_table :week_cards do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date :week_start, null: false
      t.string :style, null: false, default: "blueprint"
      t.string :layout, null: false, default: "week"
      t.jsonb :hidden_sections, null: false, default: []
      t.jsonb :hidden_projects, null: false, default: []
      t.jsonb :headlines, null: false, default: {}
      t.text :post_text
      t.timestamps
    end
    add_index :week_cards, [ :user_id, :week_start ], unique: true
  end
end
