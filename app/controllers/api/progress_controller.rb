module Api
  # The progress section for a window and the projects picked, for a
  # builder's page, a project's page or the dashboard, as the chart script asks
  # for it: what the page would render there, as JSON (ProgressViewSerializer).
  # Public, like the pages. Cached until the builder's public work changes,
  # and browsers revalidate with an ETag.
  class ProgressController < ApplicationController
    # More projects than any page shows; a longer list is not a person.
    MAX_REPOS = 50
    # A ceiling, for a change the cache key cannot see.
    EXPIRES = 10.minutes

    def show
      user = User.active.find_by(username: params[:username])
      return head(:not_found) unless user

      key = cache_key(user)
      return unless stale?(etag: key, public: true)

      json = Rails.cache.fetch(key, expires_in: EXPIRES, skip_nil: true) { view(user) }
      json ? render(json: json) : head(:unprocessable_entity)
    end

    private

    def view(user)
      service = Progress::ComposeService.new(user: user, range: range, repos: repos, rolling: true)
      ProgressViewSerializer.new(service.section).to_json if service.call
    end

    # What changes the view: the builder's public entries (their number, as
    # hiding a repo hides its entries in bulk, and their last edit), their
    # repos, their zone and today in it, and the view asked for.
    def cache_key(user)
      entries = user.entries.publicly_visible.pick(Arel.sql("COUNT(*)"), Arel.sql("MAX(entries.updated_at)"))
      today = Time.current.in_time_zone(user.zone).to_date
      [ "progress-view/v1", user.id, *entries, user.github_repos.maximum(:updated_at), user.zone.tzinfo.identifier, today, range, *repos ]
    end

    def range
      params[:range].presence_in(Progress::Window::RANGES)
    end

    def repos
      Array(params[:repo]).map(&:to_s).compact_blank.uniq.first(MAX_REPOS)
    end
  end
end
