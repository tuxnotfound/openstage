# Keys the visitor hashes on Openstage's own pages as VisitorHash now makes
# them. Each was a SHA256 of an IP address and the day, which anyone with the
# database could match by hashing every address; it becomes an HMAC of that
# hash, with a key from the app's secret. A row still matches a new view by
# the same visitor on the same day, so every day's count of visitors stays
# the same. It derives the key from its own copy of the purpose, so a later
# change to VisitorHash cannot change what it writes. One way, as the
# unkeyed hashes cannot come back.
class KeyVisitorHashes < ActiveRecord::Migration[7.1]
  PURPOSE = "page-visitors".freeze
  BATCH = 5_000

  def up
    key = Rails.application.key_generator.generate_key(PURPOSE, 32)
    %w[profile_views project_views].each do |table|
      say_with_time("Keying the visitor hashes in #{table}") { key_hashes(table, key) }
    end
  end

  # Rails' own down does nothing, so a rollback would pass and the next
  # migrate would key every hash twice.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # By id, BATCH rows at a time. The UPDATE names each row's id and its new
  # hash only, so neither the key nor an unkeyed hash reaches the SQL, or a
  # log of it.
  def key_hashes(table, key)
    last_id = 0
    keyed = 0
    loop do
      rows = connection.select_rows("SELECT id, ip_hash FROM #{table} WHERE id > #{last_id} AND ip_hash IS NOT NULL ORDER BY id LIMIT #{BATCH}")
      return keyed if rows.empty?

      values = rows.map do |id, hash|
        "(#{Integer(id)}, #{connection.quote(OpenSSL::HMAC.hexdigest("SHA256", key, hash))})"
      end
      connection.execute("UPDATE #{table} SET ip_hash = keyed.ip_hash FROM (VALUES #{values.join(', ')}) AS keyed(id, ip_hash) " \
                         "WHERE #{table}.id = keyed.id")
      last_id = Integer(rows.last.first)
      keyed += rows.size
    end
  end
end
