# Accounts I keep for testing count in no measurement: not in /admin, not in
# the owner digest, not in any gate. pcioga is my second GitHub account,
# matched by its numeric GitHub id, which survives a rename.
class AddInternalToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :internal, :boolean, default: false, null: false

    up_only do
      execute "UPDATE users SET internal = TRUE WHERE github_uid = '296907'"
    end
  end
end
