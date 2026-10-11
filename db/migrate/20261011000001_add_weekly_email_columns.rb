# F2: the weekly email to each builder and the digest to their subscribers.
# The sent_at columns stop a second run in the same week from mailing twice.
class AddWeeklyEmailColumns < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :weekly_email, :boolean, default: true, null: false
    add_column :users, :weekly_email_sent_at, :datetime
    add_column :subscriptions, :digest_sent_at, :datetime
  end
end
