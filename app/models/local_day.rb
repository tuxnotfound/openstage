# The SQL for a UTC timestamp column's calendar day in a builder's zone, so
# counts by day match the days the page shows.
module LocalDay
  def self.of(column, zone)
    "DATE((#{column} AT TIME ZONE 'UTC') AT TIME ZONE #{ActiveRecord::Base.connection.quote(zone.tzinfo.identifier)})"
  end
end
