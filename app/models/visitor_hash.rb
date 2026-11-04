# A visitor to a page on Openstage (ProfileView, ProjectView): their IP
# address hashed with the day, so Analytics counts each one once a day. Keyed
# with the app's secret: with the database alone, no one can hash every
# address until one matches.
module VisitorHash
  # The key's purpose. KeyVisitorHashes, the migration that keyed the hashes
  # stored before, derives the same key from its own copy of it.
  PURPOSE = "page-visitors".freeze

  # It keys the unkeyed hash those rows held, so a row the migration keyed
  # matches a new view by the same visitor on the same day.
  def self.of(ip, day = Date.current)
    key = Rails.application.key_generator.generate_key(PURPOSE, 32)
    OpenSSL::HMAC.hexdigest("SHA256", key, Digest::SHA256.hexdigest("#{ip}#{day}"))
  end
end
