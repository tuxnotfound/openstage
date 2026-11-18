module Analytics
  # Analytics' lists of the builder's websites, for some of their projects
  # over some days, as Openstage's script counted them there
  # (SiteVisits::RankService): where visitors came from, their ref tags and
  # their countries, by visitors, and the busiest pages, by page views; as
  # many of each as a list shows (ReportService::TOP), with what each leaves
  # out. With none of them it says why: none of the projects counts site
  # visits (:off), or nothing came in those days (:quiet).
  class GatherWebsitesService < ApplicationService
    # repos: the projects, as GithubRepos, their ids or a relation of them;
    # days: a range of days in the builder's zone, nil for every day.
    attr_accessor :user, :repos, :days
    # ranks: a Ranked by kind (SiteVisitCount::KINDS), a page's rows with
    # its project's full name while pages of several projects count; state:
    # :shown while any kind has one, else :quiet or :off.
    attr_reader :ranks, :state

    validates :user, presence: true

    private

    def execute
      @ranks = SiteVisitCount::KINDS.index_with { |kind| rank(kind) }
      @state = if ranks.values.any?(&:any?) then :shown
      elsif counting? then :quiet
      else :off
      end
    end

    def rank(kind)
      service = SiteVisits::RankService.new(repos: repos, days: days, kind: kind, top: ReportService::TOP)
      run(service) ? Ranked.new(rows: service.ranked, other: service.other) : Ranked.new(rows: [], other: 0)
    end

    # Whether one of the projects counts site visits now; read only when the
    # lists have nothing to show.
    def counting?
      slot = SiteVisits::Slot.new(user)
      GithubRepo.where(id: repos).site_script_on.any? { |repo| slot.counts?(repo) }
    end

    def run(service)
      service.call
      absorb_errors(service)
    end
  end
end
