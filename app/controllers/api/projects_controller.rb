module Api
  # A page of a builder's projects past the ones their stage gives a card,
  # found by name, sorted and filtered (Progress::Listing), as the stage's
  # list asks for it once a visitor changes it: what the stage would render
  # there, as JSON (ProjectListSerializer). Public, like the stage. Cached
  # until the builder's public work or their projects change, or the day
  # does, which moves every "last commit" and the 52 weeks; browsers
  # revalidate with an ETag.
  class ProjectsController < ApplicationController
    # A ceiling, for a change the cache key cannot see.
    EXPIRES = 10.minutes

    def show
      user = User.active.find_by(username: params[:username])
      return head(:not_found) unless user

      listing = Progress::Listing.from(params)
      key = cache_key(user, listing)
      return unless stale?(etag: key, public: true)

      json = Rails.cache.fetch(key, expires_in: EXPIRES, skip_nil: true) { view(user, listing) }
      json ? render(json: json) : head(:unprocessable_entity)
    end

    private

    def cache_key(user, listing)
      entries = user.entries.publicly_counted.pick(Arel.sql("COUNT(*)"), Arel.sql("MAX(entries.updated_at)"))
      repos = user.github_repos.pick(Arel.sql("COUNT(*)"), Arel.sql("MAX(github_repos.updated_at)"))
      [ "project-list/v1", user.id, *entries, *repos, user.zone.tzinfo.identifier, Time.current.in_time_zone(user.zone).to_date, Date.current,
        *listing.to_params.sort.flatten ]
    end

    def view(user, listing)
      list = Progress::ListService.new(user: user, listing: listing)
      ProjectListSerializer.new(list, user: user).to_json if list.call
    end
  end
end
