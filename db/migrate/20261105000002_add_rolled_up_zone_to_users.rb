class AddRolledUpZoneToUsers < ActiveRecord::Migration[7.1]
  def change
    # The zone a builder's totals were counted in (Analytics::RollUpService).
    add_column :users, :rolled_up_zone, :string
  end
end
