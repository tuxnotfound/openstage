class AddRefusedAtToRevenueAccounts < ActiveRecord::Migration[7.1]
  def change
    # When Stripe last refused the account's key on a read. While set, its
    # figures stay off the pages rather than standing stale as "Verified".
    add_column :revenue_accounts, :refused_at, :datetime
  end
end
