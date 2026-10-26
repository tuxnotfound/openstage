module Api
  # The progress section for a window and the projects picked, for a
  # builder's page, a project's page or the dashboard, as the chart script asks
  # for it: what the page would render there, as JSON (ProgressViewSerializer).
  # A page asks for the site visits it shows beside the commits too (site);
  # the builder's dashboard, for the ones they picked for it (dashboard).
  # Public, like the pages. Cached until the builder's public work changes,
  # and browsers revalidate with an ETag. A project the builder hid, and the
  # dashboard, answer for the builder alone, never into a shared cache.
  class ProgressController < ApplicationController
    # More projects than any page shows; a longer list is not a person.
    MAX_REPOS = 50
    # A ceiling, for a change the cache key cannot see.
    EXPIRES = 10.minutes
    # How fresh a chart's site visits stay: a busy site would otherwise
    # change the key on every visit.
    SITE_FRESHNESS = 5.minutes

    def show
      user = User.active.find_by(username: params[:username])
      return head(:not_found) unless user

      reveal = hidden_repo(user)
      key = cache_key(user, reveal)
      return unless stale?(etag: key, public: reveal.nil? && !dashboard?(user))

      json = Rails.cache.fetch(key, expires_in: EXPIRES, skip_nil: true) { view(user, reveal) }
      json ? render(json: json) : head(:unprocessable_entity)
    end

    private

    def view(user, reveal)
      service = Progress::ComposeService.new(user: user, range: range, repos: repos, rolling: true, reveal: reveal)
      ProgressViewSerializer.new(service.section, site: site_view(user, service.section)).to_json if service.call
    end

    def site_view(user, section)
      return unless site?(user)

      gather = SiteVisits::GatherService.new(user: user, section: section, dashboard: dashboard?(user))
      SiteVisitsViewSerializer.new(gather, section) if gather.call && gather.any?
    end

    def site?(user)
      params[:site].present? || dashboard?(user)
    end

    # The builder's own chart, which only they can ask for.
    def dashboard?(user)
      params[:dashboard].present? && current_user == user
    end

    # A repo the builder hid, asked for by the builder; nil for anyone else.
    def hidden_repo(user)
      return if params[:reveal].blank? || current_user != user

      user.github_repos.where(included: false).find_by(full_name: params[:reveal].to_s)&.full_name
    end

    # What changes the view: the builder's public entries (their number, as
    # hiding a repo hides its entries in bulk, and their last edit), their
    # repos, their zone and today in it, the view asked for, and its site
    # visits, every few minutes.
    def cache_key(user, reveal)
      entries = user.entries.publicly_visible.pick(Arel.sql("COUNT(*)"), Arel.sql("MAX(entries.updated_at)"))
      today = Time.current.in_time_zone(user.zone).to_date
      [ "progress-view/v1", user.id, *entries, user.github_repos.maximum(:updated_at), user.zone.tzinfo.identifier, today, range, reveal, *repos,
        *site_stamp(user) ]
    end

    def site_stamp(user)
      return [] unless site?(user)

      latest = SiteVisitDay.joins(:github_repo).where(github_repos: { user_id: user.id }).maximum(:updated_at)
      [ "site", dashboard?(user), user.pro?, latest.to_i / SITE_FRESHNESS.to_i ]
    end

    def range
      params[:range].presence_in(Progress::Window::RANGES)
    end

    def repos
      Array(params[:repo]).map(&:to_s).compact_blank.uniq.first(MAX_REPOS)
    end
  end
end
