module Analytics
  # Deletes the hashes of page visitors on days that are over everywhere,
  # before yesterday in UTC, as SiteVisits::ForgetVisitorsService does for
  # websites. A random id takes each one's place, for that builder alone, so
  # the raw rows can still count the day's visitors. A hash kept would lead
  # back to the address: anyone with the key could try every one.
  class ForgetVisitorsService < ApplicationService
    attr_reader :forgotten

    private

    def execute
      @before = (Date.current - 1).beginning_of_day
      @forgotten = forget(ProfileView) + forget(ProjectView)
    end

    def forget(views)
      table = views.table_name
      held = views.where(viewed_at: ...@before).where.not(ip_hash: nil)
      ids = held.group(:user_id, :ip_hash).select(:user_id, :ip_hash, "gen_random_uuid() AS visitor")
      views.connection.update(<<~SQL.squish)
        UPDATE #{table} SET visitor = ids.visitor, ip_hash = NULL FROM (#{ids.to_sql}) ids
        WHERE #{table}.user_id = ids.user_id AND #{table}.ip_hash = ids.ip_hash
          AND #{table}.ip_hash IS NOT NULL AND #{table}.viewed_at < #{views.connection.quote(@before)}
      SQL
    end
  end
end
