module SiteVisits
  # Deletes the visitors' hashes of days that are over everywhere: before
  # yesterday in UTC, since a builder's zone can run a day behind it. Their
  # visits and visitors stay in the day's totals.
  class ForgetVisitorsService < ApplicationService
    attr_reader :forgotten

    private

    def execute
      @forgotten = SiteVisitor.where(day: ...(Date.current - 1)).delete_all
    end
  end
end
