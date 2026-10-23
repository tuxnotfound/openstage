# The numbered list of what shipped and was published beside the chart on the
# builder's page, with its discs on the chart. On by default; off, the chart
# takes the whole width (REVAMP_BUILD, decided 2026-10-23).
class AddShippedListToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :shipped_list, :boolean, default: true, null: false
  end
end
