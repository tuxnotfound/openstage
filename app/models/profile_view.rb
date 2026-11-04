# One visit to a builder's page. Never the builder's own, never a bot's; the
# IP is hashed with the day and a key (VisitorHash). Analytics::RollUpService
# adds the days that are over to their totals, and the hash goes within two
# days (Analytics::ForgetVisitorsService).
class ProfileView < ApplicationRecord
  belongs_to :user
end
