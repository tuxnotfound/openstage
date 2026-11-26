# What a builder logged or published, everything but a GitHub commit, is a
# few hundred rows among thousands of commits, and every page reads it: the
# first of them per project, What's new, the dashboard's lists and their
# counts. With no index for it each read went through the builder's whole
# history (170 ms for 300 of 27,129 rows on the performance data).
class AddIndexEntriesLoggedByUser < ActiveRecord::Migration[8.1]
  def change
    add_index :entries, [ :user_id, :occurred_at ], where: "NOT (source = 'github' AND entry_type = 'shipped')",
                                                    name: "index_entries_logged_by_user"
  end
end
