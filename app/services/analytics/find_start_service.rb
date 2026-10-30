module Analytics
  # The first day each page counted each number, ever, in the builder's zone:
  # each project's first public commit and first visit and visitor to its
  # website, and the first visitor, follower and click out on the builder's
  # own page (CountService::PAGE) and on each project's page. A chart starts
  # where the numbers it draws start, and a number compares with the window
  # before only once it counted before the window began.
  class FindStartService < ApplicationService
    attr_accessor :user
    # firsts: {number's key => {page => date}}.
    attr_reader :firsts

    validates :user, presence: true

    private

    def execute
      views = days(earliest(own(user.profile_views.minimum(:viewed_at)), user.project_views.group(:repo_name).minimum(:viewed_at)))
      visits, visitors = site_visits
      @firsts = { "commits" => commits, "visits" => visits, "site_visitors" => visitors, "visitors" => views, "views" => views,
                  "follows" => follows, "clicks" => clicks }
    end

    # As the public page counts them: public, merges and dependency bumps left out.
    def commits
      days(user.entries.publicly_counted.without_tooling_noise.commits.where.not(repo_name: nil).group(:repo_name).minimum(:occurred_at))
    end

    # Counted on the builder's day already: the first day with a visit, and
    # the first with a visitor.
    def site_visits
      firsts = user.site_visit_days.group("github_repos.full_name")
                   .pluck("github_repos.full_name", Arel.sql("MIN(site_visit_days.day)"), Arel.sql("MIN(site_visit_days.day) FILTER (WHERE site_visit_days.visitors > 0)"))
      [ firsts.to_h { |page, day, _| [ page, day ] }, firsts.filter_map { |page, _, day| [ page, day ] if day }.to_h ]
    end

    # Confirmed: for the builder's page, or for one project.
    def follows
      confirmed = user.subscriptions.confirmed
      days(earliest(own(confirmed.whole_page.minimum(:confirmed_at)),
                    confirmed.projects.joins(:github_repo).group("github_repos.full_name").minimum(:confirmed_at)))
    end

    # A project's Visit and View on GitHub buttons, and the links in the
    # builder's entries: an entry's for its project, or their page with none.
    def clicks
      on_entries = user.entry_clicks.joins(:entry).group("entries.repo_name").minimum(:clicked_at).transform_keys { |repo| repo || CountService::PAGE }
      days(earliest(on_entries, user.project_clicks.group(:repo_name).minimum(:clicked_at)))
    end

    def own(time)
      time ? { CountService::PAGE => time } : {}
    end

    # {page => time} from several, the earliest for each page.
    def earliest(*parts)
      parts.reduce({}) { |all, part| all.merge(part) { |_, one, other| [ one, other ].min } }
    end

    def days(times)
      times.transform_values { |time| time.in_time_zone(user.zone).to_date }
    end
  end
end
