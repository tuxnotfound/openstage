module Analytics
  # Analytics' panels of the builder's websites, for some of their projects
  # over some days, as Openstage's script counted them there
  # (SiteVisits::RankService): where visitors came from, their ref tags and
  # their countries, by visitors, and the busiest pages, by page views; as
  # many of each as Openstage's own panels show, then Other, what the list
  # leaves out. With none of them it says why: none of the projects counts
  # site visits (:off), or nothing came in those days (:quiet).
  class GatherWebsitesService < ApplicationService
    TOPS = { "source" => ReportService::TOP, "ref" => ReportService::TOP, "country" => ReportService::TOP_COUNTRIES, "page" => ReportService::TOP }.freeze

    # repos: the projects, as GithubRepos, their ids or a relation of them;
    # days: a range of days in the builder's zone, nil for every day.
    attr_accessor :user, :repos, :days
    # ranks: [[label, count]] by kind (SiteVisitCount::KINDS), the busiest
    # first, then Other while the list leaves anything out; state: :shown
    # while any kind has one, else :quiet or :off.
    attr_reader :ranks, :state

    validates :user, presence: true

    private

    def execute
      @ranks = TOPS.to_h { |kind, top| [ kind, rank(kind, top) ] }
      @state = if ranks.values.any?(&:present?) then :shown
      elsif counting? then :quiet
      else :off
      end
    end

    def rank(kind, top)
      service = SiteVisits::RankService.new(repos: repos, days: days, kind: kind, top: top)
      return [] unless run(service)

      service.other.positive? ? service.ranked + [ [ ReportService::OTHER, service.other ] ] : service.ranked
    end

    # Whether one of the projects counts site visits now; read only when the
    # panels have nothing to show.
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
