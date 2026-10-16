# The builder's answer when an entry belongs to no project, such as a weekly
# log across several repos, so the progress section stops asking them to tag it.
class AddNoProjectToEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :entries, :no_project, :boolean, default: false, null: false
  end
end
