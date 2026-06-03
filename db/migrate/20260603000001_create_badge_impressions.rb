class CreateBadgeImpressions < ActiveRecord::Migration[7.1]
  def change
    create_table :badge_impressions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.datetime :viewed_at, null: false
      t.string :referrer
      t.string :ip_hash

      t.timestamps
    end

    add_index :badge_impressions, [ :user_id, :kind, :viewed_at ]
  end
end
