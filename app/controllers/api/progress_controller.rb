module Api
  # A chart filter's view for a window, the numbers drawn and the projects in
  # view (Progress::Filter), for a builder's page, one of their projects'
  # pages (project) or their dashboard (dashboard), as the chart script asks
  # for it: what the page would render there, as JSON (ProgressViewSerializer).
  # Public, like the pages. Cached until the builder's public work or their
  # projects change, and their site visits every few minutes; browsers
  # revalidate with an ETag. A project the builder hid, and the dashboard,
  # answer for the builder alone, and an address that asks for either never
  # goes into a shared cache, whoever asks: the cache would hand a visitor's
  # answer to the builder.
  class ProgressController < ApplicationController
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
      return unless stale?(etag: key, public: params[:reveal].blank? && params[:dashboard].blank?)

      json = Rails.cache.fetch(key, expires_in: EXPIRES, skip_nil: true) { view(user, reveal) }
      json ? render(json: json) : head(:unprocessable_entity)
    end

    private

    def view(user, reveal)
      chart = Progress::ChartService.new(user: user, range: filter.range, repos: repos, show: shown, reveal: reveal, lone: lone?,
                                         builder: dashboard?(user))
      ProgressViewSerializer.new(chart).to_json if chart.call
    end

    def filter
      @filter ||= Progress::Filter.from(params)
    end

    # A project's page asks for its one project.
    def repos
      lone? ? [ params[:project].to_s ] : filter.projects
    end

    def lone?
      params[:project].present?
    end

    # The numbers asked for, in the pages' order whatever order they came
    # in: the view is the same, and the browser gives each its line.
    def shown
      Progress::Numbers.in_order(filter.show).map(&:key)
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
    # repos (which numbers each shows), their plan, their zone and today in
    # it, their site visits every few minutes, and the view asked for.
    def cache_key(user, reveal)
      entries = user.entries.publicly_visible.pick(Arel.sql("COUNT(*)"), Arel.sql("MAX(entries.updated_at)"))
      today = Time.current.in_time_zone(user.zone).to_date
      [ "progress-view/v2", user.id, *entries, user.github_repos.maximum(:updated_at), user.pro?, user.zone.tzinfo.identifier, today,
        site_stamp(user), filter.range, reveal, dashboard?(user), lone?, "show", *shown, "projects", *repos.sort ]
    end

    def site_stamp(user)
      user.site_visit_days.maximum(:updated_at).to_i / SITE_FRESHNESS.to_i
    end
  end
end
