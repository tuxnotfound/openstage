module Api
  # The progress section for a window, the projects picked and the numbers
  # charted, for a builder's page, a project's page or the dashboard, as the
  # chart script asks for it: what the page would render there, as JSON
  # (ProgressViewSerializer). The dashboard (dashboard) counts every project's
  # site visits, shown or not, and brings the table of projects under its
  # chart. Public, like the pages. Cached until the builder's public work
  # changes, and browsers revalidate with an ETag. A project the builder hid,
  # and the dashboard, answer for the builder alone, never into a shared cache.
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
      compose = Progress::ComposeService.new(user: user, range: range, repos: repos, rolling: true, reveal: reveal)
      return unless compose.call

      section = compose.section
      numbers = Progress::NumbersService.new(user: user, section: section, picked: picked, builder: dashboard?(user))
      return unless numbers.call

      ProgressViewSerializer.new(section, numbers: numbers, table: (table(user, section, numbers) if dashboard?(user))).to_json
    end

    def table(user, section, numbers)
      list = Projects::ListService.new(user: user, section: section)
      DashboardProjectsSerializer.new(list, section, numbers) if list.call
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
    # repos, their zone and today in it, the view asked for, and their site
    # visits, every few minutes.
    def cache_key(user, reveal)
      entries = user.entries.publicly_visible.pick(Arel.sql("COUNT(*)"), Arel.sql("MAX(entries.updated_at)"))
      today = Time.current.in_time_zone(user.zone).to_date
      visits = SiteVisitDay.joins(:github_repo).where(github_repos: { user_id: user.id }).maximum(:updated_at)
      [ "progress-view/v2", user.id, *entries, user.github_repos.maximum(:updated_at), user.zone.tzinfo.identifier, today, range, reveal,
        dashboard?(user), user.pro?, visits.to_i / SITE_FRESHNESS.to_i, *repos, "numbers", *picked ]
    end

    def range
      params[:range].presence_in(Progress::Window::RANGES)
    end

    def repos
      Array(params[:repo]).map(&:to_s).compact_blank.uniq.first(MAX_REPOS)
    end

    def picked
      Array(params[:numbers]).map(&:to_s).compact_blank.uniq.first(MAX_REPOS)
    end
  end
end
