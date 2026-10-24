# One visit to a builder's page. Never the builder's own, never a bot's; the
# IP is hashed with the day. Analytics::CountService reads them.
class ProfileView < ApplicationRecord
  belongs_to :user
end
