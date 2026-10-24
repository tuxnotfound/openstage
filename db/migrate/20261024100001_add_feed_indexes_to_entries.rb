# The feed reads the newest public entries of every builder. Without an index
# on the date it read and sorted the whole table on every view; with these it
# takes the newest straight off the index: one for everything, one for what
# was logged or released (the Shipped and Posts filters), which leaves out
# commits.
class AddFeedIndexesToEntries < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :entries, :occurred_at, name: "index_entries_feed", algorithm: :concurrently,
              where: "hidden = false AND visibility = 'public'"
    add_index :entries, :occurred_at, name: "index_entries_feed_highlights", algorithm: :concurrently,
              where: "hidden = false AND visibility = 'public' AND NOT (source = 'github' AND entry_type = 'shipped')"
  end
end
