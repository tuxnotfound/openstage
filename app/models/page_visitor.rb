# The SQL for who a view's visitor was: their hash, or once it has gone the
# random id in its place, so a day's visitors count the same either way.
module PageVisitor
  def self.of(table)
    "COALESCE(#{table}.ip_hash, #{table}.visitor::text)"
  end
end
