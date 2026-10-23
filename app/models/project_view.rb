# One visit to a project's page (/:username/:repo), by its repo's full name,
# so it outlives the repo leaving the builder's list. Recorded as the
# builder's page records its own: never the builder, never a bot, the IP
# hashed with the day.
class ProjectView < ApplicationRecord
  belongs_to :user
end
