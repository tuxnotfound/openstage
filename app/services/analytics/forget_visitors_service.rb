module Analytics
  # Deletes the hashes of page visitors on days that are over everywhere,
  # before yesterday in UTC, as SiteVisits::ForgetVisitorsService does for
  # websites. A hash goes only once the rollup has counted it: without it the
  # day's visitors could never be counted.
  class ForgetVisitorsService < ApplicationService
    attr_reader :forgotten

    private

    def execute
      @before = (Date.current - 1).beginning_of_day
      @forgotten = forget(ProfileView) + forget(ProjectView)
    end

    def forget(views)
      views.joins(:user).where(viewed_at: ...@before).where.not(ip_hash: nil)
           .where("#{views.table_name}.viewed_at < users.rolled_up_to").update_all(ip_hash: nil)
    end
  end
end
