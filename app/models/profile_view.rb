# One visit to a builder's page, counted once the page runs in a browser
# (PageViews::RecordService). Never the builder's own, never a bot's; the
# IP is hashed with the day and a key (VisitorHash). Analytics::RollUpService
# adds the days that are over to their totals, and a random id takes the hash's
# place within three days (Analytics::ForgetVisitorsService).
class ProfileView < ApplicationRecord
  belongs_to :user
end
